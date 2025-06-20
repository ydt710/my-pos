-- Adds a column to transactions to explicitly track debt payments made during an order.
ALTER TABLE public.transactions
ADD COLUMN debt_paid_amount numeric NOT NULL DEFAULT 0; 