-- =============================================
-- EXPORT SCRIPT 07c: BUSINESS TABLE RLS POLICIES
-- =============================================
-- Run this script after 07b_rls_core.sql.
-- This script creates RLS policies for business tables.
-- =============================================

-- Enable RLS on business tables
ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_locations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_levels" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_product_prices" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stock_discrepancies" ENABLE ROW LEVEL SECURITY;

-- Policies for: public.reviews
DROP POLICY IF EXISTS "Anyone can view reviews" ON "public"."reviews";
CREATE POLICY "Anyone can view reviews" ON "public"."reviews"
FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Users can create own reviews" ON "public"."reviews";
CREATE POLICY "Users can create own reviews" ON "public"."reviews"
FOR INSERT
TO authenticated
WITH CHECK (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can update own reviews" ON "public"."reviews";
CREATE POLICY "Users can update own reviews" ON "public"."reviews"
FOR UPDATE
TO authenticated
USING (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()))
WITH CHECK (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete own reviews" ON "public"."reviews";
CREATE POLICY "Users can delete own reviews" ON "public"."reviews"
FOR DELETE
TO authenticated
USING (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Admin and POS can manage all reviews" ON "public"."reviews";
CREATE POLICY "Admin and POS can manage all reviews" ON "public"."reviews"
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND (profiles.is_admin = true OR profiles.role = 'pos')
  )
);

DROP POLICY IF EXISTS "Service role full access to reviews" ON "public"."reviews";
CREATE POLICY "Service role full access to reviews" ON "public"."reviews"
FOR ALL
TO service_role
USING (true);

-- Policies for: public.stock_locations
DROP POLICY IF EXISTS "Allow authenticated read access to stock locations" ON "public"."stock_locations";
CREATE POLICY "Allow authenticated read access to stock locations" ON "public"."stock_locations"
FOR SELECT
TO authenticated
USING (true);

-- Policies for: public.stock_levels
DROP POLICY IF EXISTS "Allow authenticated read access to stock levels" ON "public"."stock_levels";
CREATE POLICY "Allow authenticated read access to stock levels" ON "public"."stock_levels"
FOR SELECT
TO authenticated
USING (true);

-- Policies for: public.stock_movements
DROP POLICY IF EXISTS "Allow authenticated read access to stock movements" ON "public"."stock_movements";
CREATE POLICY "Allow authenticated read access to stock movements" ON "public"."stock_movements"
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to create stock movements" ON "public"."stock_movements";
CREATE POLICY "Allow authenticated users to create stock movements" ON "public"."stock_movements"
FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow users to update their own stock movements" ON "public"."stock_movements";
CREATE POLICY "Allow users to update their own stock movements" ON "public"."stock_movements"
FOR UPDATE
TO authenticated
USING (created_by = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()))
WITH CHECK (created_by = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Allow admins to manage stock movements" ON "public"."stock_movements";
CREATE POLICY "Allow admins to manage stock movements" ON "public"."stock_movements"
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Policies for: public.user_product_prices
DROP POLICY IF EXISTS "Allow authenticated read access to user product prices" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "Allow admins to manage user product prices" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "Admin and POS users can manage custom prices" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "Users can view own custom prices" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "Service role full access" ON "public"."user_product_prices";

-- Admin and POS users can manage all custom prices
CREATE POLICY "Admin and POS users can manage custom prices" ON "public"."user_product_prices"
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND (profiles.is_admin = true OR profiles.role = 'pos')
  )
);

-- Users can view their own custom prices
CREATE POLICY "Users can view own custom prices" ON "public"."user_product_prices"
FOR SELECT
TO authenticated
USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

-- Service role has full access
CREATE POLICY "Service role full access" ON "public"."user_product_prices"
FOR ALL
TO service_role
USING (true);

-- Policies for: public.stock_discrepancies
DROP POLICY IF EXISTS "Allow authenticated read access to stock discrepancies" ON "public"."stock_discrepancies";
CREATE POLICY "Allow authenticated read access to stock discrepancies" ON "public"."stock_discrepancies"
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to create stock discrepancies" ON "public"."stock_discrepancies";
CREATE POLICY "Allow authenticated users to create stock discrepancies" ON "public"."stock_discrepancies"
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Settings table RLS policies
CREATE POLICY "Admins can read settings"
ON public.settings FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND profiles.is_admin = true
  )
);

CREATE POLICY "Admins can update settings"
ON public.settings FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND profiles.is_admin = true
  )
);

CREATE POLICY "Admins can insert settings"
ON public.settings FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND profiles.is_admin = true
  )
);

-- Allow service role to access settings (for functions)
CREATE POLICY "Service role can access settings"
ON public.settings FOR ALL
TO service_role
USING (true)
WITH CHECK (true); 