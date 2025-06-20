-- Add balance to profiles table
ALTER TABLE public.profiles
ADD COLUMN balance numeric NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.profiles.balance IS 'The financial balance of the user. Positive means credit, negative means debt.'; 