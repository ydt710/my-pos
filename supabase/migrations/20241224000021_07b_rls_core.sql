-- =============================================
-- EXPORT SCRIPT 07b: CORE TABLE RLS POLICIES
-- =============================================
-- Run this script after 07a_storage_buckets.sql.
-- This script enables RLS and creates policies for core tables.
-- =============================================

-- Enable RLS on core tables
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;

-- Policies for: public.products
DROP POLICY IF EXISTS "Allow public read access to products" ON "public"."products";
CREATE POLICY "Allow public read access to products" ON "public"."products" 
FOR SELECT 
USING (true);  -- Allow all users to read products

DROP POLICY IF EXISTS "Allow admin full access to products" ON "public"."products";
CREATE POLICY "Allow admin full access to products" ON "public"."products" 
FOR ALL 
USING (public.is_admin());

-- Policies for: public.profiles
DROP POLICY IF EXISTS "Allow storage service" ON public.profiles;
CREATE POLICY "Allow storage service"
  ON public.profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
CREATE POLICY "Admins can manage all profiles"
  ON public.profiles
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Policies for: public.orders
DROP POLICY IF EXISTS "Users can view their own orders" ON "public"."orders";
CREATE POLICY "Users can view their own orders" ON "public"."orders" FOR SELECT USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all orders" ON "public"."orders";
CREATE POLICY "Admins can manage all orders" ON "public"."orders" FOR ALL USING (public.is_admin());

-- Policies for: public.order_items
DROP POLICY IF EXISTS "Users can view their own order items" ON "public"."order_items";
CREATE POLICY "Users can view their own order items" ON "public"."order_items" FOR SELECT USING (
  (SELECT user_id FROM public.orders WHERE id = order_id) = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
);

DROP POLICY IF EXISTS "Admins can manage all order items" ON "public"."order_items";
CREATE POLICY "Admins can manage all order items" ON "public"."order_items" FOR ALL USING (public.is_admin());

-- Policies for: public.transactions
DROP POLICY IF EXISTS "Allow users to view their own transactions" ON "public"."transactions";
CREATE POLICY "Allow users to view their own transactions" ON "public"."transactions"
FOR SELECT
TO authenticated
USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Allow admins to manage all transactions" ON "public"."transactions";
CREATE POLICY "Allow admins to manage all transactions" ON "public"."transactions"
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "POS users can view all transactions" ON "public"."transactions";
CREATE POLICY "POS users can view all transactions" ON "public"."transactions"
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        AND (is_admin = true OR role = 'pos')
    )
); 