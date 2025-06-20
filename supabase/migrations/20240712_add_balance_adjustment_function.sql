-- Adds a new function to safely adjust user balances and logs the transaction.
DROP FUNCTION IF EXISTS admin_adjust_user_balance(uuid, numeric, text);

CREATE OR REPLACE FUNCTION admin_adjust_user_balance(
  p_user_id uuid,
  p_amount numeric,
  p_note text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert a transaction to log the adjustment
  INSERT INTO public.transactions(user_id, amount, type, note)
  VALUES (p_user_id, p_amount, 'adjustment', p_note);

  -- Update the user's balance
  UPDATE public.profiles
  SET balance = balance + p_amount
  WHERE id = p_user_id;
END;
$$;

-- Add a 'note' column to the orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS note text; 