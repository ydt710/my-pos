-- =============================================
-- EXPORT SCRIPT 06d: BUSINESS FUNCTIONS
-- =============================================
-- This script creates business logic functions like pay_order, admin functions.
-- =============================================

-- Drop existing business functions with CASCADE
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.admin_adjust_balance(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.admin_complete_order(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.cancel_order_and_restock(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.handle_stock_movement() CASCADE;
DROP FUNCTION IF EXISTS public.get_order_payment_summary(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_all_orders_with_payment_summary() CASCADE;

-- CORRECTED pay_order function with proper enum casting and cash tracking
CREATE OR REPLACE FUNCTION public.pay_order(
    p_user_id UUID,
    p_order_total DECIMAL,
    p_payment_amount DECIMAL,
    p_method TEXT DEFAULT 'cash',
    p_items JSONB DEFAULT '[]'::jsonb,
    p_extra_cash_option TEXT DEFAULT 'change',
    p_is_pos_order BOOLEAN DEFAULT false
) RETURNS UUID AS $$
DECLARE
    v_order_id UUID;
    v_profile_id UUID;
    v_current_balance DECIMAL := 0;
    v_debt_payment DECIMAL := 0;
    v_order_payment DECIMAL := 0;
    v_change_amount DECIMAL := 0;
    v_overpayment DECIMAL := 0;
    v_remaining_payment DECIMAL;
    v_item JSONB;
    v_shop_location_id uuid;
BEGIN
    -- Get profile ID
    SELECT id INTO v_profile_id FROM public.profiles WHERE auth_user_id = p_user_id;
    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Profile not found for user_id: %', p_user_id;
    END IF;

    -- Get shop location for stock movements
    SELECT id INTO v_shop_location_id FROM public.stock_locations WHERE name = 'shop' LIMIT 1;
    IF v_shop_location_id IS NULL THEN
        RAISE EXCEPTION 'Shop location not found';
    END IF;

    -- Get current balance (negative = debt, positive = credit)
    SELECT COALESCE(SUM(balance_amount), 0) INTO v_current_balance 
    FROM public.transactions WHERE user_id = v_profile_id;

    -- Create the order
    INSERT INTO public.orders (
        user_id, total, status, payment_method, cash_given, 
        is_pos_order, created_at, updated_at
    ) VALUES (
        v_profile_id, p_order_total, 
        CASE WHEN p_is_pos_order THEN 'completed' ELSE 'pending' END,
        p_method, p_payment_amount, p_is_pos_order, NOW(), NOW()
    ) RETURNING id INTO v_order_id;

    -- Create order items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.order_items (order_id, product_id, quantity, price)
        VALUES (
            v_order_id,
            (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::INTEGER,
            (v_item->>'price')::DECIMAL
        );
    END LOOP;

    -- Create stock movements for each item (reduce shop stock)
    INSERT INTO public.stock_movements (product_id, from_location_id, quantity, type, note, status, order_id)
    SELECT 
        (item->>'product_id')::uuid,
        v_shop_location_id,
        (item->>'quantity')::integer,
        'sale',
        'Stock sold for order ' || v_order_id,
        'completed',
        v_order_id
    FROM jsonb_array_elements(p_items) AS item;

    -- Record the sale (always creates debt) - FIXED: Cast to enum
    INSERT INTO public.transactions (
        user_id, order_id, category, balance_amount, cash_amount, total_amount, note
    ) VALUES (
        v_profile_id, v_order_id, 
        CASE WHEN p_is_pos_order THEN 'pos_sale'::transaction_category ELSE 'online_sale'::transaction_category END,
        -p_order_total, 0, p_order_total,
        CASE WHEN p_is_pos_order THEN 'POS Sale' ELSE 'Online Sale' END || ' for order ' || v_order_id
    );

    -- Process payment if any cash is given
    IF p_payment_amount > 0 THEN
        v_remaining_payment := p_payment_amount;

        -- Step 1: Pay existing debt first (if any)
        IF v_current_balance < 0 THEN
            v_debt_payment := LEAST(ABS(v_current_balance), v_remaining_payment);
            IF v_debt_payment > 0 THEN
                INSERT INTO public.transactions (
                    user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                ) VALUES (
                    v_profile_id, v_order_id, 'debt_payment'::transaction_category, 
                    v_debt_payment, v_debt_payment, v_debt_payment,
                    'Payment towards existing debt'
                );
                v_remaining_payment := v_remaining_payment - v_debt_payment;
            END IF;
        END IF;

        -- Step 2: Pay for current order
        IF v_remaining_payment > 0 THEN
            v_order_payment := LEAST(p_order_total, v_remaining_payment);
            INSERT INTO public.transactions (
                user_id, order_id, category, balance_amount, cash_amount, total_amount, note
            ) VALUES (
                v_profile_id, v_order_id, 'cash_payment'::transaction_category, 
                v_order_payment, v_order_payment, v_order_payment,
                'Cash payment for order'
            );
            v_remaining_payment := v_remaining_payment - v_order_payment;
        END IF;

        -- Step 3: Handle any overpayment
        IF v_remaining_payment > 0 THEN
            IF p_extra_cash_option = 'change' THEN
                -- Give change (cash out, no balance effect)
                UPDATE public.orders SET change_given = v_remaining_payment WHERE id = v_order_id;
                INSERT INTO public.transactions (
                    user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                ) VALUES (
                    v_profile_id, v_order_id, 'cash_change'::transaction_category, 
                    0, -v_remaining_payment, v_remaining_payment,
                    'Change given to customer'
                );
            ELSE
                -- Credit to balance (cash_amount should reflect the cash received)
                INSERT INTO public.transactions (
                    user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                ) VALUES (
                    v_profile_id, v_order_id, 'overpayment_credit'::transaction_category, 
                    v_remaining_payment, v_remaining_payment, v_remaining_payment,
                    'Overpayment credited to balance'
                );
            END IF;
        END IF;
    END IF;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for admin balance adjustments
CREATE OR REPLACE FUNCTION public.admin_adjust_balance(p_user_id uuid, p_amount numeric, p_note text)
RETURNS void
LANGUAGE plpgsql
AS $$
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
$$;

-- Function for admins to mark pending orders as completed
CREATE OR REPLACE FUNCTION public.admin_complete_order(p_order_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Function to cancel order and restock
CREATE OR REPLACE FUNCTION public.cancel_order_and_restock(order_to_cancel uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
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
$$;

-- Function to handle stock movements
CREATE OR REPLACE FUNCTION public.handle_stock_movement()
RETURNS trigger
LANGUAGE plpgsql
AS $$
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
$$;

-- Function to get order payment summary
CREATE OR REPLACE FUNCTION public.get_order_payment_summary(p_order_id uuid)
RETURNS TABLE(
    order_id uuid,
    order_total numeric,
    cash_paid numeric,
    credit_used numeric,
    debt_remaining numeric,
    overpayment numeric
)
LANGUAGE sql
AS $$
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
$$;

-- Function to get all orders with payment summary
CREATE OR REPLACE FUNCTION public.get_all_orders_with_payment_summary()
RETURNS TABLE(
    order_id uuid,
    user_name text,
    user_email text,
    order_total numeric,
    status text,
    created_at timestamptz,
    cash_paid numeric,
    amount_due numeric
)
LANGUAGE sql
AS $$
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
$$; 