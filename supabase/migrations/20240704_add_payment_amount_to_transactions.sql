-- Add payment_amount and order_cost to transactions table
ALTER TABLE public.transactions
ADD COLUMN payment_amount numeric NOT NULL DEFAULT 0,
ADD COLUMN order_cost numeric NOT NULL DEFAULT 0;

-- Optional: Back-populate data for old transactions for consistency
-- This helps if you don't reset the database.
UPDATE public.transactions
SET 
  payment_amount = CASE 
    WHEN type IN ('payment', 'credit') THEN amount 
    ELSE 0 
  END,
  order_cost = CASE 
    WHEN type IN ('order', 'debt') THEN -amount 
    ELSE 0 
  END
WHERE payment_amount = 0 AND order_cost = 0;

-- Update note for clarity
COMMENT ON COLUMN public.transactions.amount IS 'Net effect on user balance (payment_amount - order_cost)';
COMMENT ON COLUMN public.transactions.payment_amount IS 'Actual cash/payment received from the user for this transaction';
COMMENT ON COLUMN public.transactions.order_cost IS 'The cost of the order items for this transaction'; 