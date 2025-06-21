-- Drop the insecure security definer view
DROP VIEW IF EXISTS public.order_payment_summary;

-- Create a secure function to get the payment summary for a single order
CREATE OR REPLACE FUNCTION public.get_order_payment_summary(p_order_id uuid)
RETURNS TABLE(cash_given numeric, change_given numeric, debt_total numeric, credit_total numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Security Check: Ensure the current user is an admin or the owner of the order.
  -- This is a critical security measure.
  IF NOT (
    (SELECT is_admin FROM public.profiles WHERE auth_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.orders WHERE id = p_order_id AND (user_id = auth.uid() OR created_by = auth.uid()))
  ) THEN
    RAISE EXCEPTION 'User does not have permission to view this order summary.';
  END IF;

  RETURN QUERY
    SELECT
      COALESCE(sum(CASE WHEN t.type = 'payment' THEN t.amount ELSE 0 END), 0) AS cash_given,
      COALESCE(sum(CASE WHEN t.type = 'change' THEN t.amount ELSE 0 END), 0) AS change_given,
      COALESCE(sum(CASE WHEN t.type = 'debt' THEN t.amount ELSE 0 END), 0) AS debt_total,
      COALESCE(sum(CASE WHEN t.type = 'credit' THEN t.amount ELSE 0 END), 0) AS credit_total
    FROM public.orders o
    LEFT JOIN public.transactions t ON t.order_id = o.id
    WHERE o.id = p_order_id
    GROUP BY o.id;
END;
$$; 