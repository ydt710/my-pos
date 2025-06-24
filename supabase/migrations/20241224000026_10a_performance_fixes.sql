-- =============================================
-- EXPORT SCRIPT 10a: PERFORMANCE FIXES
-- =============================================
-- This script contains performance improvements and indexing fixes.
-- Run this script after all other scripts.
-- =============================================

-- Fix 4: Create additional helpful indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_user_id_created_at ON public.transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_category_created_at ON public.transactions(category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_order_id ON public.transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_orders_user_id_status ON public.orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_auth_user_id ON public.profiles(auth_user_id);

-- Fix 5: Grant additional permissions needed for proper operation
-- These ensure the frontend can access all necessary data and functions
GRANT SELECT ON public.user_balances TO authenticated;
GRANT SELECT ON public.user_balances TO anon;

-- Ensure all sequences are properly granted
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT UPDATE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Fix 6: Add helpful comments to key tables for documentation
COMMENT ON TABLE public.transactions IS 'Dual-path accounting transactions: balance_amount affects user balance, cash_amount tracks physical cash flow';
COMMENT ON COLUMN public.transactions.category IS 'Transaction category using enum: pos_sale, online_sale, debt_payment, cash_payment, overpayment_credit, etc.';
COMMENT ON COLUMN public.transactions.balance_amount IS 'Amount that affects user balance (positive = credit, negative = debt)';
COMMENT ON COLUMN public.transactions.cash_amount IS 'Physical cash amount (positive = cash in, negative = cash out)';
COMMENT ON COLUMN public.transactions.total_amount IS 'Total transaction amount for reporting purposes';

COMMENT ON TABLE public.orders IS 'Orders table: is_pos_order=true for immediate completion, false for pending online orders';
COMMENT ON COLUMN public.orders.is_pos_order IS 'True for POS orders (completed immediately), false for online orders (pending until admin completion)';
COMMENT ON COLUMN public.orders.cash_given IS 'Physical cash given by customer';
COMMENT ON COLUMN public.orders.change_given IS 'Change given back to customer'; 