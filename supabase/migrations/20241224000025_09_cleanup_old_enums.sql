-- =============================================
-- EXPORT SCRIPT 09: CLEANUP OLD ENUM TYPES
-- =============================================
-- Run this script after all other scripts.
-- This removes the old enum types that are no longer needed.
-- =============================================

-- Drop the old enum types that are no longer needed
DROP TYPE IF EXISTS public.transaction_type CASCADE;
DROP TYPE IF EXISTS public.transaction_type_v2 CASCADE;

-- Note: The new transaction_category enum is defined in 02_tables.sql
-- and is used by the transactions table. 