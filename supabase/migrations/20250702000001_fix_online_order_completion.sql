-- =============================================
-- MIGRATION: Fix online order completion workflow
-- =============================================
-- This migration adds the complete_online_order function to properly handle
-- payment collection when customers come to collect their pending orders.
-- =============================================

-- Create the complete_online_order function
CREATE OR REPLACE FUNCTION public.complete_online_order(
    p_order_id uuid,
    p_payment_amount numeric DEFAULT 0,
    p_payment_method text DEFAULT 'cash',
    p_extra_cash_option text DEFAULT 'change'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_profile_id uuid;
    v_current_balance decimal := 0;
    v_debt_payment decimal := 0;
    v_order_payment decimal := 0;
    v_change_amount decimal := 0;
    v_overpayment decimal := 0;
    v_remaining_payment decimal;
    v_order_total decimal;
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
    
    v_profile_id := v_order.profile_id;
    v_order_total := v_order.total;
    
    -- Get current balance (negative = debt, positive = credit)
    SELECT COALESCE(SUM(balance_amount), 0) INTO v_current_balance 
    FROM public.transactions WHERE user_id = v_profile_id;
    
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
                    v_profile_id, p_order_id, 'debt_payment'::transaction_category, 
                    v_debt_payment, v_debt_payment, v_debt_payment,
                    'Payment towards existing debt during order collection'
                );
                v_remaining_payment := v_remaining_payment - v_debt_payment;
            END IF;
        END IF;

        -- Step 2: Pay for current order
        IF v_remaining_payment > 0 THEN
            v_order_payment := LEAST(v_order_total, v_remaining_payment);
            INSERT INTO public.transactions (
                user_id, order_id, category, balance_amount, cash_amount, total_amount, note
            ) VALUES (
                v_profile_id, p_order_id, 'cash_payment'::transaction_category, 
                v_order_payment, v_order_payment, v_order_payment,
                'Cash payment for online order collection'
            );
            v_remaining_payment := v_remaining_payment - v_order_payment;
        END IF;

        -- Step 3: Handle any overpayment
        IF v_remaining_payment > 0 THEN
            v_overpayment := v_remaining_payment;
            
            IF p_extra_cash_option = 'change' THEN
                -- Give change
                v_change_amount := v_overpayment;
                INSERT INTO public.transactions (
                    user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                ) VALUES (
                    v_profile_id, p_order_id, 'cash_change'::transaction_category, 
                    0, -v_change_amount, v_change_amount,
                    'Change given for overpayment'
                );
            ELSE
                -- Credit to account
                INSERT INTO public.transactions (
                    user_id, order_id, category, balance_amount, cash_amount, total_amount, note
                ) VALUES (
                    v_profile_id, p_order_id, 'overpayment_credit'::transaction_category, 
                    v_overpayment, v_overpayment, v_overpayment,
                    'Overpayment credited to account'
                );
            END IF;
        END IF;
        
        -- Update the order with payment details
        UPDATE public.orders 
        SET 
            status = 'completed', 
            updated_at = now(),
            payment_method = p_payment_method,
            cash_given = p_payment_amount,
            change_given = v_change_amount
        WHERE id = p_order_id;
    ELSE
        -- No payment provided - order completed on credit (debt remains)
        UPDATE public.orders 
        SET status = 'completed', updated_at = now()
        WHERE id = p_order_id;
    END IF;
    
    RETURN json_build_object(
        'success', true, 
        'message', 'Order completed successfully',
        'order_id', p_order_id,
        'payment_received', p_payment_amount,
        'change_given', v_change_amount,
        'order_total', v_order_total
    );
END;
$$;

-- Update the admin_complete_order function to use the new complete_online_order function
CREATE OR REPLACE FUNCTION public.admin_complete_order(
    p_order_id uuid,
    p_payment_amount numeric DEFAULT 0,
    p_payment_method text DEFAULT 'cash',
    p_extra_cash_option text DEFAULT 'change'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Just call the complete_online_order function
    RETURN public.complete_online_order(p_order_id, p_payment_amount, p_payment_method, p_extra_cash_option);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.complete_online_order(uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_complete_order(uuid, numeric, text, text) TO authenticated; 