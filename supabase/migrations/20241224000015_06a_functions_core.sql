-- =============================================
-- EXPORT SCRIPT 06a: CORE FUNCTIONS
-- =============================================
-- This script creates core helper functions and user management.
-- =============================================

-- Drop dependent RLS policies first
DROP POLICY IF EXISTS "Allow admin to manage product images" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all signatures" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all ID images" ON storage.objects;

-- Drop existing triggers first to avoid dependency issues
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_stock_movement_insert ON public.stock_movements;
DROP TRIGGER IF EXISTS on_stock_movement_update ON public.stock_movements;

-- Drop existing functions with CASCADE to handle dependencies
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.search_all_users(text) CASCADE;
DROP FUNCTION IF EXISTS public.get_user_balance_summary(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_user_balance_safe(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_admin_status(uuid, boolean) CASCADE;

-- Function to check if the current user is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = auth.uid() AND is_admin = true
  );
$$;

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (auth_user_id, email, display_name, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'display_name',
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (auth_user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Search function for users
CREATE OR REPLACE FUNCTION public.search_all_users(search_term text)
RETURNS TABLE(id uuid, display_name text, email text)
LANGUAGE sql
AS $$
  SELECT id, display_name, email
  FROM public.profiles
  WHERE display_name ILIKE '%' || search_term || '%' 
     OR email ILIKE '%' || search_term || '%'
  ORDER BY display_name
  LIMIT 20;
$$;

-- Function to get user balance summary
CREATE OR REPLACE FUNCTION public.get_user_balance_summary(p_user_id uuid)
RETURNS TABLE(user_id uuid, current_balance numeric, total_purchases numeric, total_payments numeric)
LANGUAGE sql
AS $$
  SELECT 
    p_user_id,
    COALESCE(SUM(t.balance_amount), 0) as current_balance,
    COALESCE(SUM(t.total_amount) FILTER (WHERE t.category IN ('pos_sale', 'online_sale')), 0) as total_purchases,
    COALESCE(SUM(t.cash_amount) FILTER (WHERE t.category IN ('debt_payment', 'cash_payment')), 0) as total_payments
  FROM public.transactions t
  WHERE t.user_id = p_user_id;
$$;

-- Safe user balance function that handles missing users
CREATE OR REPLACE FUNCTION public.get_user_balance_safe(p_user_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        (SELECT balance FROM user_balances WHERE user_id = p_user_id),
        0::numeric
    );
$$;

-- Function to update user admin status
CREATE OR REPLACE FUNCTION public.update_user_admin_status(target_user uuid, is_admin_status boolean)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.profiles
    SET is_admin = is_admin_status,
        updated_at = now()
    WHERE id = target_user;
END;
$$; 