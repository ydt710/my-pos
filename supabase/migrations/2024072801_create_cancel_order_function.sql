CREATE OR REPLACE FUNCTION cancel_order_and_restock(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_order_item RECORD;
    v_initial_transaction RECORD;
BEGIN
    -- Step 1: Fetch the order to ensure it exists and get user_id and total
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;

    IF v_order IS NULL THEN
        RAISE EXCEPTION 'Order with ID % not found.', p_order_id;
    END IF;

    -- Step 2: Only proceed if the order is not already cancelled
    IF v_order.status = 'cancelled' THEN
        RAISE EXCEPTION 'Order % is already cancelled.', p_order_id;
    END IF;

    -- Step 3: Find the original transaction that created the debt for this order
    SELECT * INTO v_initial_transaction FROM public.transactions
    WHERE order_id = p_order_id AND type = 'order'
    ORDER BY created_at ASC
    LIMIT 1;

    -- Step 4: If a debt-creating transaction exists, reverse it
    IF v_initial_transaction IS NOT NULL THEN
        -- Create a counteracting transaction
        INSERT INTO public.transactions(user_id, order_id, amount, method, type, note)
        VALUES (v_order.user_id, p_order_id, -v_initial_transaction.amount, 'system', 'cancellation', 'Reversal for order ' || v_order.order_number);

        -- Update the user's balance in their profile
        UPDATE public.profiles
        SET balance = balance - v_initial_transaction.amount
        WHERE auth_user_id = v_order.user_id;
    END IF;

    -- Step 5: Return stock for each item in the order
    FOR v_order_item IN
        SELECT product_id, quantity FROM public.order_items WHERE order_id = p_order_id
    LOOP
        -- Use the increase_stock helper function if it exists, otherwise update directly
        PERFORM public.increase_stock(v_order_item.product_id, v_order_item.quantity, 'shop');
    END LOOP;

    -- Step 6: Update the order status to 'cancelled'
    UPDATE public.orders
    SET status = 'cancelled', updated_at = now()
    WHERE id = p_order_id;

END;
$$;

-- Grant execution rights
GRANT EXECUTE ON FUNCTION cancel_order_and_restock(uuid) TO authenticated;

-- Set the owner to postgres to ensure it has the necessary permissions
ALTER FUNCTION cancel_order_and_restock(uuid) OWNER TO postgres; 