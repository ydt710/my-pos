-- =============================================
-- CLEANUP REMAINING DUPLICATE POLICIES
-- =============================================
-- This migration cleans up any remaining duplicate policies

-- ====================
-- PROFILES TABLE - Remove extra ALL policies
-- ====================
-- Check what profiles policies exist and remove duplicates
DROP POLICY IF EXISTS "Allow storage service" ON public.profiles;
DROP POLICY IF EXISTS "profiles_service_role_policy" ON public.profiles;

-- Create single service role policy
CREATE POLICY "profiles_service_role_policy" ON public.profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- ====================
-- REVIEWS TABLE - Consolidate ALL policies
-- ====================
DROP POLICY IF EXISTS "reviews_admin_manage_policy" ON "public"."reviews";
DROP POLICY IF EXISTS "Admins can manage all reviews" ON "public"."reviews";
DROP POLICY IF EXISTS "reviews_user_update_policy" ON "public"."reviews";
DROP POLICY IF EXISTS "Users can update own reviews" ON "public"."reviews";

-- Create single admin manage policy for reviews
CREATE POLICY "reviews_admin_manage_policy" ON "public"."reviews"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Create single user update policy for reviews
CREATE POLICY "reviews_user_update_policy" ON "public"."reviews"
FOR UPDATE TO authenticated
USING (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()))
WITH CHECK (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

-- ====================
-- SETTINGS TABLE - Consolidate ALL policies
-- ====================
DROP POLICY IF EXISTS "settings_service_role_policy" ON public.settings;
DROP POLICY IF EXISTS "settings_admin_manage_policy" ON public.settings;
DROP POLICY IF EXISTS "Service role can access settings" ON public.settings;
DROP POLICY IF EXISTS "Admins can read settings" ON public.settings;
DROP POLICY IF EXISTS "Admins can update settings" ON public.settings;

-- Create single service role policy
CREATE POLICY "settings_service_role_policy" ON public.settings
FOR ALL TO service_role
USING (true) 
WITH CHECK (true);

-- Create single admin manage policy
CREATE POLICY "settings_admin_manage_policy" ON public.settings
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- STOCK MOVEMENTS TABLE - Consolidate ALL policies
-- ====================
DROP POLICY IF EXISTS "stock_admin_manage_policy" ON "public"."stock_movements";
DROP POLICY IF EXISTS "Admins can manage stock movements" ON "public"."stock_movements";

-- Create single admin manage policy for stock movements
CREATE POLICY "stock_admin_manage_policy" ON "public"."stock_movements"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- USER PRODUCT PRICES TABLE - Consolidate ALL policies
-- ====================
DROP POLICY IF EXISTS "user_product_prices_admin_pos_manage_policy" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "Admin and POS users can manage custom prices" ON "public"."user_product_prices";

-- Create single admin/pos manage policy
CREATE POLICY "user_product_prices_admin_pos_manage_policy" ON "public"."user_product_prices"
FOR ALL TO authenticated
USING (
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = auth.uid() 
        AND profiles.role = 'pos'
    )
)
WITH CHECK (
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = auth.uid() 
        AND profiles.role = 'pos'
    )
);

-- ====================
-- LANDING PAGE TABLES - Clean up any remaining policies
-- ====================
-- Clean up any duplicate landing page policies
DROP POLICY IF EXISTS "Allow public read access to hero" ON "public"."landing_hero";
DROP POLICY IF EXISTS "Allow admin to manage hero" ON "public"."landing_hero";
DROP POLICY IF EXISTS "landing_hero_public_read" ON "public"."landing_hero";
DROP POLICY IF EXISTS "landing_hero_admin_manage" ON "public"."landing_hero";

CREATE POLICY "landing_hero_public_read" ON "public"."landing_hero"
FOR SELECT USING (true);

CREATE POLICY "landing_hero_admin_manage" ON "public"."landing_hero"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Categories
DROP POLICY IF EXISTS "Allow public read access to categories" ON "public"."landing_categories";
DROP POLICY IF EXISTS "Allow admin to manage categories" ON "public"."landing_categories";
DROP POLICY IF EXISTS "landing_categories_public_read" ON "public"."landing_categories";
DROP POLICY IF EXISTS "landing_categories_admin_manage" ON "public"."landing_categories";

CREATE POLICY "landing_categories_public_read" ON "public"."landing_categories"
FOR SELECT USING (true);

CREATE POLICY "landing_categories_admin_manage" ON "public"."landing_categories"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Stores
DROP POLICY IF EXISTS "Allow public read access to stores" ON "public"."landing_stores";
DROP POLICY IF EXISTS "Allow admin to manage stores" ON "public"."landing_stores";
DROP POLICY IF EXISTS "landing_stores_public_read" ON "public"."landing_stores";
DROP POLICY IF EXISTS "landing_stores_admin_manage" ON "public"."landing_stores";

CREATE POLICY "landing_stores_public_read" ON "public"."landing_stores"
FOR SELECT USING (true);

CREATE POLICY "landing_stores_admin_manage" ON "public"."landing_stores"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Featured Products
DROP POLICY IF EXISTS "Allow public read access to featured products" ON "public"."landing_featured_products";
DROP POLICY IF EXISTS "Allow admin to manage featured products" ON "public"."landing_featured_products";
DROP POLICY IF EXISTS "landing_featured_products_public_read" ON "public"."landing_featured_products";
DROP POLICY IF EXISTS "landing_featured_products_admin_manage" ON "public"."landing_featured_products";

CREATE POLICY "landing_featured_products_public_read" ON "public"."landing_featured_products"
FOR SELECT USING (true);

CREATE POLICY "landing_featured_products_admin_manage" ON "public"."landing_featured_products"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Testimonials
DROP POLICY IF EXISTS "Allow public read access to testimonials" ON "public"."landing_testimonials";
DROP POLICY IF EXISTS "Allow admin to manage testimonials" ON "public"."landing_testimonials";
DROP POLICY IF EXISTS "landing_testimonials_public_read" ON "public"."landing_testimonials";
DROP POLICY IF EXISTS "landing_testimonials_admin_manage" ON "public"."landing_testimonials";

CREATE POLICY "landing_testimonials_public_read" ON "public"."landing_testimonials"
FOR SELECT USING (true);

CREATE POLICY "landing_testimonials_admin_manage" ON "public"."landing_testimonials"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin()); 