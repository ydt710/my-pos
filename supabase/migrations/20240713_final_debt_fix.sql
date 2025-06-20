-- Final correction for the pay_order function.

-- Drop the previous function
DROP FUNCTION IF EXISTS public.pay_order(uuid, numeric, numeric, numeric, text, jsonb, text, boolean);

-- Re-create the function with robust balance and debt logic.
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
    v_new_balance numeric;
    v_balance_change numeric;
    v_cash_kept numeric;
    v_net_payment numeric;
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

    -- Step 2: Generate a new order number.
    v_order_number := 'O-' || to_char(CURRENT_DATE, 'YYYY-') || nextval('public.order_number_seq');

    -- Step 3: Insert the order.
    INSERT INTO orders (user_id, total, status, payment_method, is_pos_order, order_number)
    VALUES (p_user_id, p_order_total, 'completed', p_method, p_is_pos_order, v_order_number)
    RETURNING id INTO v_order_id;

    -- Step 4: Insert order items and decrease stock.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::int;
        v_price := (v_item->>'price')::numeric;
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);
        PERFORM public.decrease_stock(v_product_id, v_quantity, 'shop');
    END LOOP;

    -- Step 5: Determine the net payment and balance change.
    v_net_payment := p_payment_amount + p_credit_used;
    v_balance_change := v_net_payment - p_order_total;
    
    -- Step 6: Handle cash calculations (change vs. credit).
    IF p_extra_cash_option = 'change' AND v_balance_change > 0 THEN
        -- Give change, so no credit is applied to user's balance.
        v_cash_kept := p_payment_amount - v_balance_change;
        v_balance_change := 0;
    ELSE
        -- No change given (or 'credit' option selected), so all cash is kept.
        v_cash_kept := p_payment_amount;
    END IF;

    -- Step 7: Log the transaction with the final calculated amounts.
    INSERT INTO transactions (user_id, order_id, amount, method, type, note, order_cost, payment_amount, credit_used)
    VALUES (p_user_id, v_order_id, v_balance_change, p_method, 'order', 'Order ' || v_order_number, p_order_total, v_cash_kept, p_credit_used);
    
    -- Step 8: Update user balance in the profiles table if there's a change.
    IF v_balance_change != 0 THEN
      UPDATE profiles
      SET balance = balance + v_balance_change
      WHERE id = p_user_id
      RETURNING balance INTO v_new_balance;
    END IF;

    RETURN v_order_id;
END;
$$; 