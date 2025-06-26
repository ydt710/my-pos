-- =============================================
-- MIGRATION: Fix order_number usage and stock movement notes
-- =============================================
-- 1. Update pay_order to set order_number and use it in stock movement notes
-- 2. Backfill order_number for existing orders
-- =============================================

-- 1. Update pay_order function
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean);

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
    v_order_number text;
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

    -- Generate order_number
    v_order_number := generate_invoice_number();

    -- Create the order
    INSERT INTO public.orders (
        user_id, total, status, payment_method, cash_given, 
        is_pos_order, created_at, updated_at, order_number
    ) VALUES (
        v_profile_id, p_order_total, 
        CASE WHEN p_is_pos_order THEN 'completed' ELSE 'pending' END,
        p_method, p_payment_amount, p_is_pos_order, NOW(), NOW(), v_order_number
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
        'Stock sold for order ' || v_order_number,
        'completed',
        v_order_id
    FROM jsonb_array_elements(p_items) AS item;

    -- Record the sale (always creates debt)
    INSERT INTO public.transactions (
        user_id, order_id, category, balance_amount, cash_amount, total_amount, note
    ) VALUES (
        v_profile_id, v_order_id, 
        CASE WHEN p_is_pos_order THEN 'pos_sale'::transaction_category ELSE 'online_sale'::transaction_category END,
        -p_order_total, 0, p_order_total,
        CASE WHEN p_is_pos_order THEN 'POS Sale' ELSE 'Online Sale' END || ' for order ' || v_order_number
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

-- 2. Backfill order_number for existing orders that are missing it
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT id FROM public.orders WHERE order_number IS NULL OR order_number = ''
    LOOP
        UPDATE public.orders
        SET order_number = generate_invoice_number()
        WHERE id = rec.id;
    END LOOP;
END $$; 