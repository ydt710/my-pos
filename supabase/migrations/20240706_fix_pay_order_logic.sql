-- Corrects the pay_order function to handle credit payments and use the correct user ID field.

-- Drop existing versions to prevent conflicts
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean);
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text);
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean, numeric);

-- Create the updated function
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
    -- Validate stock for each item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        SELECT public.get_stock_by_location(v_product_id, 'shop') INTO v_stock;
        IF v_stock IS NULL OR v_stock < v_quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %', v_product_id;
        END IF;
    END LOOP;

    -- Insert order
    INSERT INTO orders (user_id, total, status, payment_method, is_pos_order)
    VALUES (p_user_id, p_order_total, 'completed', p_method, p_is_pos_order)
    RETURNING id INTO v_order_id;

    -- Insert order_items and update quantity
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        v_price := (v_item->>'price')::numeric;
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);
        PERFORM public.decrease_stock(v_product_id, v_quantity, 'shop');
    END LOOP;

    -- Log transaction for credit part
    IF p_credit_used > 0 THEN
      INSERT INTO transactions (user_id, order_id, amount, method, type, note, payment_amount, order_cost)
      VALUES (p_user_id, v_order_id, -p_credit_used, 'credit', 'payment', 'Paid using credit', 0, p_credit_used);
    END IF;

    -- Log transaction for cash part
    IF p_payment_amount > 0 THEN
      INSERT INTO transactions (user_id, order_id, amount, method, type, note, payment_amount, order_cost)
      VALUES (p_user_id, v_order_id, p_payment_amount, p_method, 'payment', 'Paid with cash', p_payment_amount, p_order_total - p_credit_used);
    END IF;

    -- Calculate total change in balance
    v_balance_change := p_payment_amount + p_credit_used - p_order_total;
    
    -- Update user balance
    UPDATE profiles
    SET balance = balance + v_balance_change
    WHERE id = p_user_id
    RETURNING balance INTO v_new_balance;

    RETURN v_order_id;
END;
$$; 