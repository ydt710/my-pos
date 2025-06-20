-- Adds the credit_used column to the transactions table for better auditing.
ALTER TABLE public.transactions
ADD COLUMN credit_used numeric DEFAULT 0; 