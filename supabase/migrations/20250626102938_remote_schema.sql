create sequence "public"."order_number_seq";

drop policy "Only admins can update settings" on "public"."settings";

drop policy "Users can view settings" on "public"."settings";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.admin_adjust_balance(p_user_id uuid, p_amount numeric, p_note text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_amount > 0 THEN
        -- For credit adjustments: Use 'overpayment_credit' so it shows in cash collected stats
        -- Set both balance_amount and cash_amount like real overpayments
        INSERT INTO public.transactions (
            user_id, category, balance_amount, cash_amount, total_amount, 
            description, affects_balance, affects_cash_collected, method, note
        ) VALUES (
            p_user_id, 
            'overpayment_credit'::transaction_category,
            p_amount,
            p_amount,  -- Set cash_amount so it appears in cash collected statistics
            p_amount,
            'Admin credit adjustment',
            TRUE,
            TRUE,
            'manual',
            p_note
        );
    ELSE
        -- For debt adjustments: Use 'debit_adjustment' and we'll update stats to include it
        INSERT INTO public.transactions (
            user_id, category, balance_amount, cash_amount, total_amount, 
            description, affects_balance, affects_cash_collected, method, note
        ) VALUES (
            p_user_id, 
            'debit_adjustment'::transaction_category,
            p_amount,  -- Negative amount
            0,         -- No cash involved in debt adjustments
            ABS(p_amount),
            'Admin debt adjustment',
            TRUE,
            FALSE,
            'manual',
            p_note
        );
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_complete_order(p_order_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_order RECORD;
    v_cash_collected numeric := 0;
BEGIN
    -- Get the order details
    SELECT o.*, p.id as profile_id 
    INTO v_order
    FROM public.orders o
    JOIN public.profiles p ON o.user_id = p.id
    WHERE o.id = p_order_id AND o.deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Order not found');
    END IF;
    
    IF v_order.status != 'pending' THEN
        RETURN json_build_object('success', false, 'error', 'Order is not pending');
    END IF;
    
    -- Calculate how much cash was collected for this order
    SELECT COALESCE(SUM(t.cash_amount), 0)
    INTO v_cash_collected
    FROM public.transactions t
    WHERE t.order_id = p_order_id AND t.category IN ('cash_payment', 'debt_payment');
    
    -- Mark order as completed
    UPDATE public.orders 
    SET status = 'completed', updated_at = now()
    WHERE id = p_order_id;
    
    RETURN json_build_object(
        'success', true, 
        'message', 'Order marked as completed',
        'order_id', p_order_id,
        'cash_collected', v_cash_collected
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_order_and_restock(order_to_cancel uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_shop_location_id uuid;
BEGIN
    -- Get the Shop Location ID
    SELECT id INTO v_shop_location_id FROM public.stock_locations WHERE name = 'shop' LIMIT 1;
    IF v_shop_location_id IS NULL THEN
        RAISE EXCEPTION 'Shop location not found. A stock_locations entry with the name "shop" is required.';
    END IF;

    UPDATE public.orders
    SET 
        deleted_at = now(),
        deleted_by = auth.uid(),
        deleted_by_role = (SELECT role FROM public.profiles WHERE auth_user_id = auth.uid()),
        status = 'cancelled'
    WHERE id = order_to_cancel;

    -- This will reverse the balance effect of the sale
    INSERT INTO public.transactions (user_id, order_id, category, balance_amount, total_amount, description, affects_balance)
    SELECT
        o.user_id,
        order_to_cancel,
        'cancellation',
        o.total, -- Positive amount to reverse the negative sale
        o.total,
        'Order cancellation for order ' || order_to_cancel,
        TRUE
    FROM public.orders o
    WHERE o.id = order_to_cancel;

    -- Restock items
    WITH restock_items AS (
        SELECT oi.product_id, oi.quantity
        FROM public.order_items oi
        WHERE oi.order_id = order_to_cancel
    )
    INSERT INTO public.stock_movements (product_id, to_location_id, quantity, type, note, status, order_id)
    SELECT 
        ri.product_id,
        v_shop_location_id,
        ri.quantity,
        'restock',
        'Restocked due to order cancellation',
        'completed',
        order_to_cancel
    FROM restock_items ri;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_all_orders_with_payment_summary()
 RETURNS TABLE(order_id uuid, user_name text, user_email text, order_total numeric, status text, created_at timestamp with time zone, cash_paid numeric, amount_due numeric)
 LANGUAGE sql
AS $function$
  SELECT 
    o.id,
    p.display_name,
    p.email,
    o.total,
    o.status,
    o.created_at,
    COALESCE(SUM(t.cash_amount) FILTER (WHERE t.category IN ('cash_payment', 'debt_payment')), 0),
    GREATEST(0, o.total - COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category IN ('cash_payment', 'credit_payment', 'debt_payment')), 0))
  FROM public.orders o
  JOIN public.profiles p ON o.user_id = p.id
  LEFT JOIN public.transactions t ON o.id = t.order_id
  WHERE o.deleted_at IS NULL
  GROUP BY o.id, p.display_name, p.email, o.total, o.status, o.created_at
  ORDER BY o.created_at DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.get_cash_collected_chart_data(p_period text, p_start_date timestamp with time zone, p_end_date timestamp with time zone)
 RETURNS TABLE(period_start timestamp with time zone, cash_collected numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start,
        COALESCE(SUM(t.cash_amount), 0) AS cash_collected
    FROM
        generate_series(
            date_trunc(p_period, p_start_date),
            p_end_date,
            ('1 ' || p_period)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(p_period, t.created_at) = gs.period_start
                             AND t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_cash_collected_events(p_start_date timestamp with time zone, p_end_date timestamp with time zone)
 RETURNS TABLE(period timestamp with time zone, cash_collected numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        t.created_at as period,
        t.cash_amount as cash_collected
    FROM
        public.transactions t
    WHERE
        t.category IN ('debt_payment', 'cash_payment', 'overpayment_credit')
        AND t.created_at BETWEEN p_start_date AND p_end_date
        AND t.cash_amount > 0
    ORDER BY
        t.created_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_credit_over_time(p_period text, p_start_date timestamp with time zone, p_end_date timestamp with time zone)
 RETURNS TABLE(period timestamp with time zone, credit numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start as period,
        COALESCE(SUM(t.balance_amount), 0) AS credit
    FROM
        generate_series(
            date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, p_start_date),
            p_end_date,
            (CASE WHEN p_period = 'day' THEN '1 hour' ELSE '1 ' || p_period END)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, t.created_at) = gs.period_start
                             AND t.category = 'overpayment_credit'
                             AND t.created_at BETWEEN p_start_date AND p_end_date
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_debt_created_vs_paid(filter_option text)
 RETURNS TABLE(period timestamp with time zone, debt_created numeric, debt_paid numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        time_series.period::timestamptz,
        COALESCE(SUM(CASE WHEN t.category IN ('pos_sale', 'online_sale', 'debit_adjustment') 
                          AND t.balance_amount < 0
                          AND EXISTS (
                              SELECT 1 FROM public.user_balances p 
                              WHERE p.user_id = t.user_id AND p.balance < 0
                          )
                          THEN ABS(t.balance_amount) ELSE 0 END), 0) AS debt_created,
        COALESCE(SUM(CASE WHEN t.category = 'debt_payment' THEN t.balance_amount ELSE 0 END), 0) AS debt_paid
    FROM
        (SELECT generate_series(
            date_trunc(
                CASE WHEN filter_option = 'today' THEN 'hour' ELSE 'day' END,
                (CASE
                    WHEN filter_option = 'today' THEN date_trunc('day', now())
                    WHEN filter_option = 'week' THEN date_trunc('week', now())
                    WHEN filter_option = 'month' THEN date_trunc('month', now())
                    WHEN filter_option = 'year' THEN date_trunc('year', now())
                    ELSE now() - interval '1 year'
                END)
            ),
            now(),
            (CASE WHEN filter_option = 'today' THEN '1 hour' ELSE '1 day' END)::interval
        ) AS period) AS time_series
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN filter_option = 'today' THEN 'hour' ELSE 'day' END, t.created_at) = time_series.period
    GROUP BY
        time_series.period
    ORDER BY
        time_series.period;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_debt_over_time(p_period text, p_start_date timestamp with time zone, p_end_date timestamp with time zone)
 RETURNS TABLE(period timestamp with time zone, debt numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        gs.period_start as period,
        COALESCE(SUM(ABS(t.balance_amount)), 0) AS debt
    FROM
        generate_series(
            date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, p_start_date),
            p_end_date,
            (CASE WHEN p_period = 'day' THEN '1 hour' ELSE '1 ' || p_period END)::interval
        ) AS gs(period_start)
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN p_period = 'day' THEN 'hour' ELSE p_period END, t.created_at) = gs.period_start
                             AND t.category IN ('pos_sale', 'online_sale', 'debit_adjustment')
                             AND t.balance_amount < 0
                             AND t.created_at BETWEEN p_start_date AND p_end_date
                             AND EXISTS (
                                 SELECT 1 FROM public.user_balances p 
                                 WHERE p.user_id = t.user_id AND p.balance < 0
                             )
    GROUP BY
        gs.period_start
    ORDER BY
        gs.period_start;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_order_payment_summary(p_order_id uuid)
 RETURNS TABLE(order_id uuid, order_total numeric, cash_paid numeric, credit_used numeric, debt_remaining numeric, overpayment numeric)
 LANGUAGE sql
AS $function$
  SELECT 
    p_order_id,
    o.total,
    COALESCE(SUM(t.cash_amount) FILTER (WHERE t.category = 'cash_payment'), 0),
    COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category = 'credit_payment'), 0),
    CASE WHEN o.total - COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category IN ('cash_payment', 'credit_payment')), 0) > 0 
         THEN o.total - COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category IN ('cash_payment', 'credit_payment')), 0)
         ELSE 0 
    END,
    COALESCE(SUM(t.balance_amount) FILTER (WHERE t.category = 'overpayment_credit'), 0)
  FROM public.orders o
  LEFT JOIN public.transactions t ON o.id = t.order_id
  WHERE o.id = p_order_id
  GROUP BY o.id, o.total;
$function$
;

CREATE OR REPLACE FUNCTION public.get_revenue_chart_data(filter_option text)
 RETURNS TABLE(period timestamp with time zone, revenue numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        time_series.period,
        COALESCE(SUM(CASE WHEN t.category IN ('sale', 'pos_sale', 'online_sale') THEN ABS(t.balance_amount) ELSE 0 END), 0) AS revenue
    FROM
        (SELECT generate_series(
            date_trunc(
                CASE WHEN filter_option = 'today' THEN 'hour' ELSE 'day' END,
                (CASE
                    WHEN filter_option = 'today' THEN date_trunc('day', now())
                    WHEN filter_option = 'week' THEN date_trunc('week', now())
                    WHEN filter_option = 'month' THEN date_trunc('month', now())
                    WHEN filter_option = 'year' THEN date_trunc('year', now())
                    ELSE now() - interval '1 year'
                END)
            )::timestamptz,
            now()::timestamptz,
            (CASE WHEN filter_option = 'today' THEN '1 hour' ELSE '1 day' END)::interval
        ) AS period) AS time_series
    LEFT JOIN
        public.transactions t ON date_trunc(CASE WHEN filter_option = 'today' THEN 'hour' ELSE 'day' END, t.created_at) = time_series.period
    GROUP BY
        time_series.period
    ORDER BY
        time_series.period;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_stock_movement()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_stock integer;
BEGIN
    -- Get current stock level
    SELECT quantity INTO v_current_stock
    FROM public.stock_levels
    WHERE product_id = NEW.product_id AND location_id = COALESCE(NEW.to_location_id, NEW.from_location_id);

    -- Update stock based on movement type
    IF NEW.type = 'sale' AND NEW.from_location_id IS NOT NULL THEN
        -- Reduce stock from source location
        UPDATE public.stock_levels
        SET quantity = quantity - NEW.quantity,
            updated_at = now()
        WHERE product_id = NEW.product_id AND location_id = NEW.from_location_id;
    ELSIF NEW.type = 'restock' AND NEW.to_location_id IS NOT NULL THEN
        -- Add stock to destination location
        INSERT INTO public.stock_levels (product_id, location_id, quantity, created_at, updated_at)
        VALUES (NEW.product_id, NEW.to_location_id, NEW.quantity, now(), now())
        ON CONFLICT (product_id, location_id)
        DO UPDATE SET quantity = stock_levels.quantity + NEW.quantity, updated_at = now();
    END IF;

    RETURN NEW;
END;
$function$
;


