-- This function updates the admin_adjust_user_balance function to intelligently
-- tag transactions as 'payment' when a positive adjustment is made to an account with a negative balance.

-- Drop the existing function to replace it
DROP FUNCTION IF EXISTS public.admin_adjust_user_balance(uuid, numeric, text, boolean);

-- Re-create the function with intelligent transaction tagging
CREATE OR REPLACE FUNCTION public.admin_adjust_user_balance(
    p_user_id uuid,
    p_amount numeric,
    p_note text,
    p_is_debt boolean
)
RETURNS void AS $$
DECLARE
    v_adjustment_amount numeric;
    v_current_balance numeric;
    v_transaction_type text;
BEGIN
    v_adjustment_amount := p_amount;
    IF p_is_debt THEN
        v_adjustment_amount := -p_amount;
    END IF;

    -- Get the user's current balance BEFORE the transaction
    SELECT balance INTO v_current_balance FROM public.profiles WHERE id = p_user_id;

    -- Determine the correct transaction type
    v_transaction_type := 'adjustment'; -- Default type
    IF v_adjustment_amount > 0 AND v_current_balance < 0 THEN
      -- This is a payment towards existing debt
      v_transaction_type := 'payment';
    END IF;

    -- Update user balance in the profiles table
    UPDATE public.profiles
    SET balance = balance + v_adjustment_amount
    WHERE id = p_user_id;

    -- Log the transaction with the appropriate type
    INSERT INTO public.transactions(user_id, amount, type, note, method)
    VALUES (p_user_id, v_adjustment_amount, v_transaction_type, p_note, 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 