-- =============================================
-- MIGRATION: Fix user_balances Security Definer Issue
-- =============================================
-- This migration addresses the Supabase security linter warning:
-- "View `public.user_balances` is defined with the SECURITY DEFINER property"
-- 
-- We change it to SECURITY INVOKER to respect the permissions and RLS policies
-- of the querying user rather than the view creator.
-- 
-- This is safe because:
-- 1. Both underlying tables (profiles, transactions) have proper RLS policies
-- 2. The view will now respect user permissions through the underlying table policies
-- 3. Admins/POS users can still see all data through the RLS policies
-- =============================================

-- Drop the existing view to recreate it with proper security settings
DROP VIEW IF EXISTS public.user_balances;

-- Recreate the view with SECURITY INVOKER
CREATE VIEW public.user_balances 
WITH (security_invoker = on) AS
SELECT
    p.id AS user_id,
    p.auth_user_id,
    p.display_name AS name,
    p.email,
    p.phone_number AS phone,
    COALESCE(SUM(t.balance_amount), 0) AS balance
FROM 
    public.profiles p
LEFT JOIN 
    public.transactions t ON p.id = t.user_id
GROUP BY 
    p.id, p.auth_user_id, p.display_name, p.email, p.phone_number;

-- Restore the necessary grants
GRANT SELECT ON public.user_balances TO authenticated;
GRANT SELECT ON public.user_balances TO anon;

-- Add a comment explaining the security model
COMMENT ON VIEW public.user_balances IS 
'User balance aggregation view with SECURITY INVOKER. Access is controlled by RLS policies on underlying tables (profiles, transactions).'; 