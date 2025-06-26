-- =============================================
-- FINAL POLICY CONSOLIDATION
-- =============================================
-- This migration properly consolidates policies to eliminate multiple 
-- permissive policies for the same role and action

-- 1. PRODUCTS TABLE - Keep only one SELECT policy
DROP POLICY IF EXISTS "products_admin_manage" ON "public"."products";

-- Single admin policy for non-SELECT actions only
CREATE POLICY "products_admin_write" ON "public"."products"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "products_admin_update" ON "public"."products"
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "products_admin_delete" ON "public"."products"
FOR DELETE TO authenticated
USING (public.is_admin());

-- 2. TRANSACTIONS TABLE - Remove overlapping SELECT policy
DROP POLICY IF EXISTS "transactions_admin_manage" ON "public"."transactions";

-- Admin policies for specific actions (non-SELECT)
CREATE POLICY "transactions_admin_insert" ON "public"."transactions"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "transactions_admin_update" ON "public"."transactions"
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "transactions_admin_delete" ON "public"."transactions"
FOR DELETE TO authenticated
USING (public.is_admin());

-- 3. STOCK MOVEMENTS - Fix overlap by removing ALL policy
DROP POLICY IF EXISTS "stock_movements_admin_manage" ON "public"."stock_movements";

-- Specific admin policies for non-SELECT actions
CREATE POLICY "stock_movements_admin_update" ON "public"."stock_movements"
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "stock_movements_admin_delete" ON "public"."stock_movements"
FOR DELETE TO authenticated
USING (public.is_admin());

-- 4. USER_PRODUCT_PRICES - Completely rebuild to avoid overlap
DROP POLICY IF EXISTS "user_product_prices_select_consolidated" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "user_product_prices_manage_consolidated" ON "public"."user_product_prices";

-- Single SELECT policy
CREATE POLICY "user_product_prices_select" ON "public"."user_product_prices"
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

-- Admin/POS policies for non-SELECT actions
CREATE POLICY "user_product_prices_insert" ON "public"."user_product_prices"
FOR INSERT TO authenticated
WITH CHECK (
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = (SELECT auth.uid()) 
        AND profiles.role = 'pos'
    )
);

CREATE POLICY "user_product_prices_update" ON "public"."user_product_prices"
FOR UPDATE TO authenticated
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

CREATE POLICY "user_product_prices_delete" ON "public"."user_product_prices"
FOR DELETE TO authenticated
USING (
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = (SELECT auth.uid()) 
        AND profiles.role = 'pos'
    )
);

-- 5. LANDING PAGE TABLES - Consolidate by removing admin SELECT policies
-- These currently have both _access (SELECT for all) and _admin (ALL for authenticated)
-- Solution: Keep _access for SELECT, modify _admin to be INSERT/UPDATE/DELETE only

DROP POLICY IF EXISTS "landing_hero_admin" ON "public"."landing_hero";
DROP POLICY IF EXISTS "landing_categories_admin" ON "public"."landing_categories";
DROP POLICY IF EXISTS "landing_stores_admin" ON "public"."landing_stores";
DROP POLICY IF EXISTS "landing_featured_products_admin" ON "public"."landing_featured_products";
DROP POLICY IF EXISTS "landing_testimonials_admin" ON "public"."landing_testimonials";

-- Recreate admin policies for write operations only
CREATE POLICY "landing_hero_admin" ON "public"."landing_hero"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "landing_hero_admin_update" ON "public"."landing_hero"
FOR UPDATE TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

CREATE POLICY "landing_hero_admin_delete" ON "public"."landing_hero"
FOR DELETE TO authenticated
USING (public.is_admin());

CREATE POLICY "landing_categories_admin" ON "public"."landing_categories"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "landing_categories_admin_update" ON "public"."landing_categories"
FOR UPDATE TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

CREATE POLICY "landing_categories_admin_delete" ON "public"."landing_categories"
FOR DELETE TO authenticated
USING (public.is_admin());

CREATE POLICY "landing_stores_admin" ON "public"."landing_stores"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "landing_stores_admin_update" ON "public"."landing_stores"
FOR UPDATE TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

CREATE POLICY "landing_stores_admin_delete" ON "public"."landing_stores"
FOR DELETE TO authenticated
USING (public.is_admin());

CREATE POLICY "landing_featured_products_admin" ON "public"."landing_featured_products"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "landing_featured_products_admin_update" ON "public"."landing_featured_products"
FOR UPDATE TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

CREATE POLICY "landing_featured_products_admin_delete" ON "public"."landing_featured_products"
FOR DELETE TO authenticated
USING (public.is_admin());

CREATE POLICY "landing_testimonials_admin" ON "public"."landing_testimonials"
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "landing_testimonials_admin_update" ON "public"."landing_testimonials"
FOR UPDATE TO authenticated
USING (public.is_admin()) 
WITH CHECK (public.is_admin());

CREATE POLICY "landing_testimonials_admin_delete" ON "public"."landing_testimonials"
FOR DELETE TO authenticated
USING (public.is_admin()); 