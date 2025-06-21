-- Dropping all functions first to ensure a clean slate
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean);
DROP FUNCTION IF EXISTS get_dashboard_stats();
DROP FUNCTION IF EXISTS get_cash_in_stats();
DROP FUNCTION IF EXISTS get_revenue_chart_data(text);
DROP FUNCTION IF EXISTS get_debt_created_vs_paid(text);
DROP FUNCTION IF EXISTS admin_mark_order_completed(uuid);

-- 1. Create the new pay_order function
CREATE OR REPLACE FUNCTION public.pay_order(
    p_user_id uuid,
    p_order_total numeric,
    p_payment_amount numeric,
    p_method text,
    p_items jsonb,
    p_extra_cash_option text,
    p_is_pos_order boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_profile RECORD;
    v_order_id uuid;
    v_order_cost numeric := p_order_total;
    v_remaining_payment numeric := p_payment_amount;
    v_credit_to_use numeric := 0;
    v_debt_payment numeric := 0;
    v_new_balance numeric;
    v_transaction_amount numeric;
    v_note text;
    v_initial_status text;
BEGIN
    -- Step 1: Get user profile and lock the row
    SELECT * INTO v_user_profile FROM public.profiles WHERE auth_user_id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found for auth_user_id %', p_user_id;
    END IF;

    -- Step 2: Determine initial order status
    IF p_is_pos_order AND p_payment_amount >= p_order_total THEN
        v_initial_status := 'completed';
    ELSE
        v_initial_status := 'pending';
    END IF;

    -- Step 3: Create the order
    INSERT INTO public.orders (user_id, total, status, payment_method, is_pos_order)
    VALUES (v_user_profile.id, p_order_total, v_initial_status, p_method, p_is_pos_order)
    RETURNING id INTO v_order_id;

    -- Step 4: Insert order items
    INSERT INTO public.order_items (order_id, product_id, quantity, price)
    SELECT
        v_order_id,
        (item->>'product_id')::uuid,
        (item->>'quantity')::integer,
        (item->>'price')::numeric
    FROM jsonb_array_elements(p_items) AS item;

    -- Step 5: Handle the payment logic
    -- Use existing credit first
    IF v_user_profile.balance > 0 THEN
        v_credit_to_use := LEAST(v_user_profile.balance, v_order_cost);
        v_order_cost := v_order_cost - v_credit_to_use;
    END IF;

    -- Apply payment to remaining order cost
    IF v_order_cost > 0 THEN
        v_debt_payment := LEAST(v_remaining_payment, v_order_cost);
        v_remaining_payment := v_remaining_payment - v_debt_payment;
    END IF;
    
    -- The rest of the payment is overpayment
    -- This adds to the user's balance.
    
    -- Calculate the new balance
    v_new_balance := v_user_profile.balance - p_order_total + p_payment_amount;
    
    -- The net effect on balance for the transaction record
    v_transaction_amount := p_payment_amount - p_order_total;

    -- Create the transaction record
    v_note := 'Payment for new order. Cash received: ' || p_payment_amount;
    IF p_extra_cash_option = 'credit' AND v_remaining_payment > 0 THEN
        v_note := v_note || '. Overpayment of ' || v_remaining_payment || ' added to credit.';
    END IF;

    INSERT INTO public.transactions (user_id, order_id, type, method, amount, payment_amount, order_cost, credit_used, debt_paid_amount, note)
    VALUES (
        v_user_profile.id,
        v_order_id,
        'payment',
        p_method,
        v_transaction_amount,
        p_payment_amount,
        p_order_total,
        v_credit_to_use,
        v_debt_payment,
        v_note
    );

    -- Update user's balance
    UPDATE public.profiles SET balance = v_new_balance WHERE id = v_user_profile.id;

    -- Update order status if it was pending and is now fully paid
    IF v_initial_status = 'pending' AND v_order_cost <= 0 THEN
        UPDATE public.orders SET status = 'completed', updated_at = now() WHERE id = v_order_id;
    END IF;

    RETURN v_order_id;
END;
$$; 


-- 2. Create the statistics functions
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_orders bigint;
    v_total_revenue numeric;
    v_cash_to_collect numeric;
    v_top_products json;
BEGIN
    -- Total orders
    SELECT count(*) INTO v_total_orders FROM public.orders WHERE deleted_at IS NULL;

    -- Total revenue from completed orders
    SELECT COALESCE(sum(total), 0) INTO v_total_revenue FROM public.orders WHERE status = 'completed';

    -- Cash to collect from pending orders
    SELECT COALESCE(sum(total), 0) INTO v_cash_to_collect FROM public.orders WHERE status = 'pending';

    -- Top 5 selling products
    SELECT json_agg(p) INTO v_top_products FROM (
        SELECT 
            pr.name, 
            sum(oi.quantity) AS quantity
        FROM public.order_items oi
        JOIN public.products pr ON oi.product_id = pr.id
        GROUP BY pr.name
        ORDER BY quantity DESC
        LIMIT 5
    ) p;

    RETURN json_build_object(
        'totalOrders', v_total_orders,
        'totalRevenue', v_total_revenue,
        'cashToCollect', v_cash_to_collect,
        'topProducts', v_top_products
    );
END;
$$;

CREATE OR REPLACE FUNCTION get_cash_in_stats()
RETURNS json
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN (SELECT json_build_object(
        'today', COALESCE(SUM(payment_amount) FILTER (WHERE created_at >= a.today_start), 0),
        'week', COALESCE(SUM(payment_amount) FILTER (WHERE created_at >= a.week_start), 0),
        'month', COALESCE(SUM(payment_amount) FILTER (WHERE created_at >= a.month_start), 0),
        'year', COALESCE(SUM(payment_amount) FILTER (WHERE created_at >= a.year_start), 0),
        'all_time', COALESCE(SUM(payment_amount), 0)
    )
    FROM public.transactions,
         (SELECT 
             date_trunc('day', now()) as today_start,
             date_trunc('week', now()) as week_start,
             date_trunc('month', now()) as month_start,
             date_trunc('year', now()) as year_start
         ) a
    WHERE type = 'payment');
END;
$$;

CREATE OR REPLACE FUNCTION get_revenue_chart_data(filter_option text)
RETURNS TABLE(period text, revenue numeric)
LANGUAGE plpgsql
AS $$
BEGIN
    IF filter_option = 'today' THEN
        RETURN QUERY
        SELECT to_char(date_trunc('hour', o.created_at), 'HH24:MI') as period,
               COALESCE(sum(o.total), 0) as revenue
        FROM public.orders o
        WHERE o.status = 'completed' AND o.created_at >= date_trunc('day', now())
        GROUP BY period
        ORDER BY period;
    ELSIF filter_option = 'week' THEN
        RETURN QUERY
        SELECT to_char(date_trunc('day', o.created_at), 'Dy') as period,
               COALESCE(sum(o.total), 0) as revenue
        FROM public.orders o
        WHERE o.status = 'completed' AND o.created_at >= date_trunc('week', now())
        GROUP BY period
        ORDER BY date_trunc('day', o.created_at);
    ELSIF filter_option = 'month' THEN
        RETURN QUERY
        SELECT to_char(date_trunc('week', o.created_at), 'W') as period,
               COALESCE(sum(o.total), 0) as revenue
        FROM public.orders o
        WHERE o.status = 'completed' AND o.created_at >= date_trunc('month', now())
        GROUP BY period
        ORDER BY date_trunc('week', o.created_at);
    ELSE -- 'year'
        RETURN QUERY
        SELECT to_char(date_trunc('month', o.created_at), 'Mon') as period,
               COALESCE(sum(o.total), 0) as revenue
        FROM public.orders o
        WHERE o.status = 'completed' AND o.created_at >= date_trunc('year', now())
        GROUP BY period
        ORDER BY date_trunc('month', o.created_at);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION get_debt_created_vs_paid(filter_option text)
RETURNS TABLE(period text, debt_created numeric, debt_paid numeric)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_date date;
BEGIN
    -- Determine the start date based on the filter option
    SELECT 
        CASE 
            WHEN filter_option = 'today' THEN date_trunc('day', now())
            WHEN filter_option = 'week' THEN date_trunc('week', now())
            WHEN filter_option = 'month' THEN date_trunc('month', now())
            ELSE date_trunc('year', now())
        END INTO v_start_date;

    RETURN QUERY
    WITH date_series AS (
        SELECT generate_series(
            v_start_date, 
            now(), 
            CASE 
                WHEN filter_option = 'today' THEN '1 hour'::interval
                WHEN filter_option = 'week' THEN '1 day'::interval
                WHEN filter_option = 'month' THEN '1 week'::interval
                ELSE '1 month'::interval
            END
        ) as period_start
    )
    SELECT 
        CASE 
            WHEN filter_option = 'today' THEN to_char(ds.period_start, 'HH24:MI')
            WHEN filter_option = 'week' THEN to_char(ds.period_start, 'Dy')
            WHEN filter_option = 'month' THEN 'Week ' || to_char(ds.period_start, 'W')
            ELSE to_char(ds.period_start, 'Mon')
        END as period,
        COALESCE(sum(t.order_cost - t.payment_amount - t.credit_used), 0) as debt_created,
        COALESCE(sum(t.debt_paid_amount), 0) as debt_paid
    FROM date_series ds
    LEFT JOIN public.transactions t ON date_trunc(
        CASE 
            WHEN filter_option = 'today' THEN 'hour'
            WHEN filter_option = 'week' THEN 'day'
            WHEN filter_option = 'month' THEN 'week'
            ELSE 'month'
        END, t.created_at) = ds.period_start
    GROUP BY ds.period_start
    ORDER BY ds.period_start;
END;
$$; 

-- 3. Create the admin_mark_order_completed function
CREATE OR REPLACE FUNCTION admin_mark_order_completed(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_existing_payment_amount numeric;
BEGIN
    -- Step 1: Fetch the order details
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % not found', p_order_id;
    END IF;

    -- Step 2: Prevent re-completion or completing a cancelled order
    IF v_order.status = 'completed' THEN
        RAISE NOTICE 'Order % is already completed.', p_order_id;
        RETURN;
    END IF;
    IF v_order.status = 'cancelled' THEN
        RAISE EXCEPTION 'Cannot complete a cancelled order.';
    END IF;

    -- Step 3: Check if a payment transaction already exists to avoid double counting
    SELECT COALESCE(SUM(payment_amount), 0) INTO v_existing_payment_amount
    FROM public.transactions
    WHERE order_id = p_order_id AND type = 'payment';

    -- If payment already covers the total, just update status.
    IF v_existing_payment_amount >= v_order.total THEN
        UPDATE public.orders SET status = 'completed', updated_at = now() WHERE id = p_order_id;
        RAISE NOTICE 'Order % payment already recorded. Status updated to completed.', p_order_id;
        RETURN;
    END IF;

    -- Step 4: Record the payment transaction
    -- This assumes the admin is confirming a cash payment for the full amount.
    INSERT INTO public.transactions (user_id, order_id, amount, method, type, note, payment_amount, debt_paid_amount)
    VALUES (
        v_order.user_id,
        p_order_id,
        v_order.total,      -- This amount positively affects user balance
        'cash',             -- Assume cash payment from admin action
        'payment',
        'Manual completion by admin for order ' || v_order.order_number,
        v_order.total,      -- This amount contributes to cash collected stats
        v_order.total       -- This amount contributes to debt paid stats
    );
    
    -- Step 5: Update the user's balance
    UPDATE public.profiles
    SET balance = balance + v_order.total
    WHERE id = v_order.user_id;

    -- Step 6: Update the order status to 'completed'
    UPDATE public.orders
    SET status = 'completed', updated_at = now()
    WHERE id = p_order_id;

END;
$$;

GRANT EXECUTE ON FUNCTION admin_mark_order_completed(uuid) TO authenticated;
ALTER FUNCTION admin_mark_order_completed(uuid) OWNER TO postgres; 