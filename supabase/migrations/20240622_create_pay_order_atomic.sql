-- Migration: Create atomic pay_order function for checkout
CREATE OR REPLACE FUNCTION public.pay_order(
    p_user_id uuid,
    p_order_total numeric,
    p_payment_amount numeric,
    p_method text,
    p_items jsonb, -- array of {product_id, quantity, price}
    p_extra_cash_option text DEFAULT 'change' -- 'change' or 'credit'
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
    v_new_stock int;
    v_change numeric;
    v_credit numeric;
    v_debt numeric;
BEGIN
    -- 1. Validate stock for each item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        SELECT quantity INTO v_stock FROM products WHERE id = v_product_id FOR UPDATE;
        IF v_stock IS NULL OR v_stock < v_quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %', v_product_id;
        END IF;
    END LOOP;

    -- 2. Insert order
    INSERT INTO orders (user_id, total, status, payment_method)
    VALUES (p_user_id, p_order_total, 'completed', p_method)
    RETURNING id INTO v_order_id;

    -- 3. Insert order_items and update quantity
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        v_price := (v_item->>'price')::numeric;
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);
        UPDATE products SET quantity = quantity - v_quantity WHERE id = v_product_id;
    END LOOP;

    -- 4. Log the order as a negative transaction
    INSERT INTO transactions (user_id, order_id, amount, method, type, note)
    VALUES (p_user_id, v_order_id, -p_order_total, p_method, 'order', 'Order placed');

    -- 5. Log the payment as a positive transaction
    IF p_payment_amount > 0 THEN
      INSERT INTO transactions (user_id, order_id, amount, method, type, note)
      VALUES (p_user_id, v_order_id, p_payment_amount, p_method, 'payment', 'Order payment');
    END IF;

    -- 6. Handle overpayment (credit)
    v_change := GREATEST(p_payment_amount - p_order_total, 0);
    v_debt := GREATEST(p_order_total - p_payment_amount, 0);
    v_credit := 0;
    IF v_change > 0 THEN
        IF p_extra_cash_option = 'credit' THEN
            v_credit := v_change;
            v_change := 0;
            -- Log credit in transactions
            INSERT INTO transactions (user_id, order_id, amount, method, type, note)
            VALUES (p_user_id, v_order_id, v_credit, p_method, 'credit', 'Overpayment credited');
        END IF;
    END IF;
    IF v_debt > 0 THEN
        -- Log debt in transactions
        INSERT INTO transactions (user_id, order_id, amount, method, type, note)
        VALUES (p_user_id, v_order_id, -v_debt, p_method, 'debt', 'Order debt');
    END IF;

    RETURN v_order_id;
END;
$$; 