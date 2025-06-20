-- Corrects the pay_order function balance and transaction logic.

-- Drop the function created by the previous migration.
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, numeric, text, jsonb, text, boolean);

-- Re-create the function with the corrected logic.
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
    v_item jsonb;
    v_product_id uuid;
    v_quantity int;
    v_price numeric;
    v_stock int;
    v_new_balance numeric;
    v_balance_change numeric;
BEGIN
    -- Step 1: Validate stock for each item.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        SELECT public.get_stock_by_location(v_product_id, 'shop') INTO v_stock;
        IF v_stock IS NULL OR v_stock < v_quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %', v_product_id;
        END IF;
    END LOOP;

    -- Step 2: Insert the order.
    INSERT INTO orders (user_id, total, status, payment_method, is_pos_order)
    VALUES (p_user_id, p_order_total, 'completed', p_method, p_is_pos_order)
    RETURNING id INTO v_order_id;

    -- Step 3: Insert order items and decrease stock.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        v_price := (v_item->>'price')::numeric;
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);
        PERFORM public.decrease_stock(v_product_id, v_quantity, 'shop');
    END LOOP;

    -- Step 4: Log transactions.
    -- Log debt for the full order cost.
    INSERT INTO transactions (user_id, order_id, amount, method, type, note, order_cost)
    VALUES (p_user_id, v_order_id, -p_order_total, p_method, 'debt', 'Order ' || v_order_id, p_order_total);

    -- Log payment if cash/card was tendered.
    IF p_payment_amount > 0 THEN
        INSERT INTO transactions (user_id, order_id, amount, method, type, note, payment_amount)
        VALUES (p_user_id, v_order_id, p_payment_amount, p_method, 'payment', 'Payment for order ' || v_order_id, p_payment_amount);
    END IF;

    -- Log credit usage for auditing (amount is 0 so it doesn't affect balance sum).
    IF p_credit_used > 0 THEN
        INSERT INTO transactions (user_id, order_id, amount, method, type, note, order_cost)
        VALUES (p_user_id, v_order_id, 0, 'credit', 'credit_payment', 'Used ' || p_credit_used || ' credit for order ' || v_order_id, p_credit_used);
    END IF;

    -- Step 5: Calculate the final change in the user's balance.
    -- The net effect is simply cash_in minus goods_out. Using credit is a transfer of existing balance.
    v_balance_change := p_payment_amount - p_order_total;
    
    -- Update user balance in the profiles table.
    UPDATE profiles
    SET balance = balance + v_balance_change
    WHERE id = p_user_id
    RETURNING balance INTO v_new_balance;

    RETURN v_order_id;
END;
$$; 