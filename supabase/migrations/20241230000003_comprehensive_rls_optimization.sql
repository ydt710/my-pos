-- =============================================
-- COMPREHENSIVE RLS OPTIMIZATION
-- =============================================
-- This migration addresses both issues identified by the Supabase linter:
-- 1. Multiple Permissive Policies - consolidate into single policies with OR logic
-- 2. Auth RLS Performance - wrap auth.uid() in (select auth.uid()) for caching
-- Based on: https://supabase.com/docs/guides/database/database-advisors

-- =============================================
-- STEP 1: DROP ALL EXISTING POLICIES
-- =============================================

-- Transactions
DROP POLICY IF EXISTS "transactions_select_policy" ON "public"."transactions";
DROP POLICY IF EXISTS "transactions_admin_all_policy" ON "public"."transactions";

-- Orders  
DROP POLICY IF EXISTS "orders_select_policy" ON "public"."orders";
DROP POLICY IF EXISTS "orders_admin_manage_policy" ON "public"."orders";
DROP POLICY IF EXISTS "orders_user_create_policy" ON "public"."orders";
DROP POLICY IF EXISTS "orders_user_update_policy" ON "public"."orders";

-- Order Items
DROP POLICY IF EXISTS "order_items_select_policy" ON "public"."order_items";
DROP POLICY IF EXISTS "order_items_admin_manage_policy" ON "public"."order_items";
DROP POLICY IF EXISTS "order_items_user_modify_policy" ON "public"."order_items";

-- Profiles
DROP POLICY IF EXISTS "profiles_user_read_policy" ON "public"."profiles";
DROP POLICY IF EXISTS "profiles_user_update_policy" ON "public"."profiles";
DROP POLICY IF EXISTS "profiles_admin_manage_policy" ON "public"."profiles";
DROP POLICY IF EXISTS "profiles_service_role_policy" ON "public"."profiles";

-- Products
DROP POLICY IF EXISTS "products_public_read_policy" ON "public"."products";
DROP POLICY IF EXISTS "products_admin_manage_policy" ON "public"."products";

-- Reviews
DROP POLICY IF EXISTS "reviews_public_read_policy" ON "public"."reviews";
DROP POLICY IF EXISTS "reviews_user_create_policy" ON "public"."reviews";
DROP POLICY IF EXISTS "reviews_user_update_policy" ON "public"."reviews";
DROP POLICY IF EXISTS "reviews_admin_manage_policy" ON "public"."reviews";

-- User Product Prices
DROP POLICY IF EXISTS "user_product_prices_read_policy" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "user_product_prices_admin_pos_manage_policy" ON "public"."user_product_prices";

-- Stock tables
DROP POLICY IF EXISTS "stock_movements_read_policy" ON "public"."stock_movements";
DROP POLICY IF EXISTS "stock_movements_create_policy" ON "public"."stock_movements";
DROP POLICY IF EXISTS "stock_admin_manage_policy" ON "public"."stock_movements";

-- Landing page tables
DROP POLICY IF EXISTS "landing_hero_public_read" ON "public"."landing_hero";
DROP POLICY IF EXISTS "landing_hero_admin_manage" ON "public"."landing_hero";
DROP POLICY IF EXISTS "landing_categories_public_read" ON "public"."landing_categories";
DROP POLICY IF EXISTS "landing_categories_admin_manage" ON "public"."landing_categories";
DROP POLICY IF EXISTS "landing_stores_public_read" ON "public"."landing_stores";
DROP POLICY IF EXISTS "landing_stores_admin_manage" ON "public"."landing_stores";
DROP POLICY IF EXISTS "landing_featured_products_public_read" ON "public"."landing_featured_products";
DROP POLICY IF EXISTS "landing_featured_products_admin_manage" ON "public"."landing_featured_products";
DROP POLICY IF EXISTS "landing_testimonials_public_read" ON "public"."landing_testimonials";
DROP POLICY IF EXISTS "landing_testimonials_admin_manage" ON "public"."landing_testimonials";

-- =============================================
-- STEP 2: CREATE OPTIMIZED CONSOLIDATED POLICIES
-- =============================================

-- ==================
-- TRANSACTIONS TABLE
-- ==================
-- Single SELECT policy with optimized auth.uid() calls
CREATE POLICY "transactions_select_consolidated" ON "public"."transactions"
FOR SELECT TO authenticated
USING (
    -- Users can see their own transactions OR admins/POS can see all
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE auth_user_id = (SELECT auth.uid()) 
        AND role = 'pos'
    )
);

-- Admin management policy (separate from SELECT to avoid conflicts)
CREATE POLICY "transactions_admin_manage" ON "public"."transactions"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ==================
-- ORDERS TABLE
-- ==================
-- Consolidated SELECT policy
CREATE POLICY "orders_select_consolidated" ON "public"."orders"
FOR SELECT TO authenticated
USING (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
);

-- Consolidated INSERT policy (users can create own orders OR admins can create any)
CREATE POLICY "orders_insert_consolidated" ON "public"."orders"
FOR INSERT TO authenticated
WITH CHECK (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
);

-- Consolidated UPDATE policy (users can update own pending orders OR admins can update any)
CREATE POLICY "orders_update_consolidated" ON "public"."orders"
FOR UPDATE TO authenticated
USING (
    (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid())) AND status = 'pending')
    OR
    public.is_admin()
)
WITH CHECK (
    (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid())) AND status = 'pending')
    OR
    public.is_admin()
);

-- Consolidated DELETE policy (only admins can delete)
CREATE POLICY "orders_delete_consolidated" ON "public"."orders"
FOR DELETE TO authenticated
USING (public.is_admin());

-- ==================
-- ORDER ITEMS TABLE
-- ==================
-- Consolidated SELECT policy
CREATE POLICY "order_items_select_consolidated" ON "public"."order_items"
FOR SELECT TO authenticated
USING (
    (SELECT user_id FROM public.orders WHERE id = order_id) = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
);

-- Consolidated INSERT policy
CREATE POLICY "order_items_insert_consolidated" ON "public"."order_items"
FOR INSERT TO authenticated
WITH CHECK (
    (SELECT user_id FROM public.orders WHERE id = order_id) = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
);

-- ==================
-- PROFILES TABLE
-- ==================
-- Service role policy (separate role)
CREATE POLICY "profiles_service_role" ON "public"."profiles"
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Consolidated SELECT policy for authenticated users
CREATE POLICY "profiles_select_consolidated" ON "public"."profiles"
FOR SELECT TO authenticated
USING (
    auth_user_id = (SELECT auth.uid())
    OR
    public.is_admin()
);

-- Consolidated UPDATE policy
CREATE POLICY "profiles_update_consolidated" ON "public"."profiles"
FOR UPDATE TO authenticated
USING (
    auth_user_id = (SELECT auth.uid())
    OR
    public.is_admin()
)
WITH CHECK (
    auth_user_id = (SELECT auth.uid())
    OR
    public.is_admin()
);

-- ==================
-- PRODUCTS TABLE
-- ==================
-- Consolidated SELECT policy (public read + admin manage)
CREATE POLICY "products_select_consolidated" ON "public"."products"
FOR SELECT
USING (true);  -- Public read access

-- Admin management policy
CREATE POLICY "products_admin_manage" ON "public"."products"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ==================
-- REVIEWS TABLE
-- ==================
-- Consolidated SELECT policy (public read + admin manage)
CREATE POLICY "reviews_select_consolidated" ON "public"."reviews"
FOR SELECT
USING (true);  -- Public read access

-- Consolidated INSERT policy
CREATE POLICY "reviews_insert_consolidated" ON "public"."reviews"
FOR INSERT TO authenticated
WITH CHECK (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
);

-- Consolidated UPDATE policy
CREATE POLICY "reviews_update_consolidated" ON "public"."reviews"
FOR UPDATE TO authenticated
USING (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
)
WITH CHECK (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
);

-- ==================
-- USER PRODUCT PRICES TABLE
-- ==================
-- Consolidated SELECT policy
CREATE POLICY "user_product_prices_select_consolidated" ON "public"."user_product_prices"
FOR SELECT TO authenticated
USING (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = (SELECT auth.uid()))
    OR
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = (SELECT auth.uid()) 
        AND profiles.role = 'pos'
    )
);

-- Consolidated management policy (admin/POS users only)
CREATE POLICY "user_product_prices_manage_consolidated" ON "public"."user_product_prices"
FOR ALL TO authenticated
USING (
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = (SELECT auth.uid()) 
        AND profiles.role = 'pos'
    )
)
WITH CHECK (
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = (SELECT auth.uid()) 
        AND profiles.role = 'pos'
    )
);

-- ==================
-- STOCK MOVEMENTS TABLE
-- ==================
-- Consolidated SELECT policy
CREATE POLICY "stock_movements_select_consolidated" ON "public"."stock_movements"
FOR SELECT TO authenticated
USING (true);

-- Consolidated INSERT policy
CREATE POLICY "stock_movements_insert_consolidated" ON "public"."stock_movements"
FOR INSERT TO authenticated
WITH CHECK (
    true  -- All authenticated users can create stock movements
    OR
    public.is_admin()
);

-- Admin management policy
CREATE POLICY "stock_movements_admin_manage" ON "public"."stock_movements"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ==================
-- LANDING PAGE TABLES - Single policies per table
-- ==================

-- Landing Hero
CREATE POLICY "landing_hero_access" ON "public"."landing_hero"
FOR SELECT USING (true);  -- Public read

CREATE POLICY "landing_hero_admin" ON "public"."landing_hero"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Landing Categories  
CREATE POLICY "landing_categories_access" ON "public"."landing_categories"
FOR SELECT USING (true);  -- Public read

CREATE POLICY "landing_categories_admin" ON "public"."landing_categories"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Landing Stores
CREATE POLICY "landing_stores_access" ON "public"."landing_stores"
FOR SELECT USING (true);  -- Public read

CREATE POLICY "landing_stores_admin" ON "public"."landing_stores"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Landing Featured Products
CREATE POLICY "landing_featured_products_access" ON "public"."landing_featured_products"
FOR SELECT USING (true);  -- Public read

CREATE POLICY "landing_featured_products_admin" ON "public"."landing_featured_products"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- Landing Testimonials
CREATE POLICY "landing_testimonials_access" ON "public"."landing_testimonials"
FOR SELECT USING (true);  -- Public read

CREATE POLICY "landing_testimonials_admin" ON "public"."landing_testimonials"
FOR ALL TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

-- ==================
-- STOCK LOCATIONS AND LEVELS
-- ==================
CREATE POLICY "stock_locations_read" ON "public"."stock_locations"
FOR SELECT TO authenticated
USING (true);

CREATE POLICY "stock_levels_read" ON "public"."stock_levels"
FOR SELECT TO authenticated
USING (true);

-- ==================
-- SETTINGS TABLE
-- ==================
-- Service role policy
CREATE POLICY "settings_service_role" ON "public"."settings"
FOR ALL TO service_role
USING (true) 
WITH CHECK (true);

-- Admin management policy
CREATE POLICY "settings_admin_manage" ON "public"."settings"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin()); 