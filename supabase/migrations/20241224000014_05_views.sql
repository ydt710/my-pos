-- =============================================
-- EXPORT SCRIPT 05: VIEWS (CLEAN REWRITE)
-- =============================================
-- Run this script after 04_foreign_keys.sql.
-- This script is idempotent.
-- =============================================

CREATE OR REPLACE VIEW "public"."user_balances" AS
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