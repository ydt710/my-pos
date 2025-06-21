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
    INSERT INTO public.transactions (user_id, order_id, amount, method, type, note, payment_amount, debt_paid)
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