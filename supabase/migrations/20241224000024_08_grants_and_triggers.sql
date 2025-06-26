-- =============================================
-- EXPORT SCRIPT 08: GRANTS & TRIGGERS
-- =============================================
-- Run this script after 07d_rls_landing.sql.
-- This script contains permission grants and triggers.
-- =============================================

-- Grants for superuser (postgres)
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;

-- Grants for anonymous users (anon)
-- Products can be viewed by anon users for landing page
GRANT SELECT ON TABLE public.products TO anon;
GRANT SELECT ON TABLE public.landing_hero TO anon;
GRANT SELECT ON TABLE public.landing_categories TO anon;
GRANT SELECT ON TABLE public.landing_stores TO anon;
GRANT SELECT ON TABLE public.landing_featured_products TO anon;
GRANT SELECT ON TABLE public.landing_testimonials TO anon;

-- Grants for logged-in users (authenticated)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.order_items TO authenticated;
GRANT SELECT ON TABLE public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.reviews TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.stock_locations TO authenticated;
GRANT SELECT ON TABLE public.stock_levels TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.stock_movements TO authenticated;
GRANT SELECT ON TABLE public.transactions TO authenticated;
GRANT SELECT ON TABLE public.user_product_prices TO authenticated;
GRANT SELECT ON public.user_balances TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_discrepancies TO authenticated;
GRANT SELECT ON TABLE public.landing_hero TO authenticated;
GRANT SELECT ON TABLE public.landing_categories TO authenticated;
GRANT SELECT ON TABLE public.landing_stores TO authenticated;
GRANT SELECT ON TABLE public.landing_featured_products TO authenticated;
GRANT SELECT ON TABLE public.landing_testimonials TO authenticated;
GRANT ALL ON TABLE public.landing_hero TO authenticated;
GRANT ALL ON TABLE public.landing_categories TO authenticated;
GRANT ALL ON TABLE public.landing_stores TO authenticated;
GRANT ALL ON TABLE public.landing_featured_products TO authenticated;
GRANT ALL ON TABLE public.landing_testimonials TO authenticated;

-- Grants for sequences (including landing page sequences)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT UPDATE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grants for functions
-- Core functions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_all_users(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_balance_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_balance_safe(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_admin_status(uuid, boolean) TO authenticated;

-- Dashboard functions
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cash_in_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_top_buyers(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_users_by_balance(integer, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_outstanding_debt_by_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_comprehensive_balance(uuid) TO authenticated;

-- Chart and reporting functions
GRANT EXECUTE ON FUNCTION public.get_revenue_chart_data(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_debt_created_vs_paid(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cash_collected_chart_data(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cash_paid_over_time(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_credit_over_time(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_debt_over_time(text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_total_spent_top_users(timestamptz, timestamptz, integer) TO authenticated;

-- Business functions
GRANT EXECUTE ON FUNCTION public.pay_order(uuid, numeric, numeric, text, jsonb, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_balance(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_complete_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_order_and_restock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_stock_movement() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_order_payment_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_orders_with_payment_summary() TO authenticated;

-- Stock management functions
GRANT EXECUTE ON FUNCTION public.confirm_production_done(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_stock_transfer(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_stock_transfer(uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_transfers_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_shop_transfers_count() TO authenticated;

-- Utility functions
GRANT EXECUTE ON FUNCTION public.generate_invoice_number() TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_tax_amount(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_shipping_fee(numeric, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_store_settings() TO authenticated;

-- =============================================
-- TRIGGERS
-- =============================================

-- Create trigger for new user profile creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Create triggers for stock movement handling
DROP TRIGGER IF EXISTS on_stock_movement_insert ON public.stock_movements;
CREATE TRIGGER on_stock_movement_insert
  AFTER INSERT ON public.stock_movements
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM 'pending')
  EXECUTE FUNCTION public.handle_stock_movement();

DROP TRIGGER IF EXISTS on_stock_movement_update ON public.stock_movements;
CREATE TRIGGER on_stock_movement_update
  AFTER UPDATE ON public.stock_movements
  FOR EACH ROW
  WHEN (OLD.status = 'pending' AND NEW.status IS DISTINCT FROM 'pending')
  EXECUTE FUNCTION public.handle_stock_movement(); 