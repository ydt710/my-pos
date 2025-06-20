-- Updates the pay_order function to calculate and record debt payments from order overpayments.

DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, numeric, text, jsonb, text, boolean);

CREATE OR REPLACE FUNCTION public.pay_order(
    p_user_id uuid,
    p_order_total numeric,
    p_payment_amount numeric,
    p_credit_used numeric,
    p_method text,
    p_items jsonb,
    p_extra_cash_option text DEFAULT 'change',
    p_is_pos_order boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id uuid;
    v_order_number text;
    v_item jsonb;
    v_product_id uuid;
    v_quantity int;
    v_price numeric;
    v_stock int;
    v_balance_change numeric;
    v_cash_kept numeric;
    v_net_payment numeric;
    v_current_balance numeric;
    v_debt_paid_from_surplus numeric := 0;
BEGIN
    -- Step 1: Validate stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        SELECT public.get_stock_by_location(v_product_id, 'shop') INTO v_stock;
        IF v_stock IS NULL OR v_stock < v_quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %', v_product_id;
        END IF;
    END LOOP;

    -- Step 2: Generate order number and create order
    v_order_number := 'O-' || to_char(CURRENT_DATE, 'YYYY-') || nextval('public.order_number_seq');
    INSERT INTO orders (user_id, total, status, payment_method, is_pos_order, order_number)
    VALUES (p_user_id, p_order_total, 'completed', p_method, p_is_pos_order, v_order_number)
    RETURNING id INTO v_order_id;

    -- Step 3: Insert order items and decrease stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        v_price := (v_item->>'price')::numeric;
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);
        PERFORM public.decrease_stock(v_product_id, v_quantity, 'shop');
    END LOOP;

    -- Step 4: Get current balance to check for existing debt.
    SELECT balance INTO v_current_balance FROM public.profiles WHERE id = p_user_id;

    -- Step 5: Determine the net payment and total balance change.
    v_net_payment := p_payment_amount + p_credit_used;
    v_balance_change := v_net_payment - p_order_total;
    
    -- Step 6: Check if any part of a surplus payment is paying off old debt.
    IF v_balance_change > 0 AND v_current_balance < 0 THEN
        v_debt_paid_from_surplus := LEAST(v_balance_change, abs(v_current_balance));
    END IF;

    -- Step 7: Handle cash calculations (change vs. credit).
    IF p_extra_cash_option = 'change' AND v_balance_change > 0 THEN
        v_cash_kept := p_payment_amount - v_balance_change;
        -- User's balance does not get credited because they received change.
        v_balance_change := 0;
    ELSE
        -- No change given (or 'credit' option selected), so all cash is kept.
        v_cash_kept := p_payment_amount;
    END IF;

    -- Step 8: Log the transaction, now including any debt paid amount.
    INSERT INTO transactions (user_id, order_id, amount, method, type, note, order_cost, payment_amount, credit_used, debt_paid_amount)
    VALUES (p_user_id, v_order_id, v_balance_change, p_method, 'order', 'Order ' || v_order_number, p_order_total, v_cash_kept, p_credit_used, v_debt_paid_from_surplus);
    
    -- Step 9: Update user balance in the profiles table.
    -- The final balance update is the original balance + the net change from the transaction.
    -- This is handled by adding the original v_balance_change, which includes any surplus.
    UPDATE profiles
    SET balance = balance + (v_net_payment - p_order_total)
    WHERE id = p_user_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql