-- =============================================
-- CONSOLIDATE RLS POLICIES - FIX DUPLICATE POLICIES
-- =============================================
-- This migration removes duplicate RLS policies and consolidates them properly
-- Run this migration to fix the "multiple permissive policies" issue

-- ====================
-- TRANSACTIONS TABLE
-- ====================
-- Remove all existing transaction policies first
DROP POLICY IF EXISTS "Allow users to view their own transactions" ON "public"."transactions";
DROP POLICY IF EXISTS "Allow admins to manage all transactions" ON "public"."transactions";
DROP POLICY IF EXISTS "POS users can view all transactions" ON "public"."transactions";

-- Create a single consolidated SELECT policy for transactions
-- This policy handles all three user types in one policy to avoid conflicts
CREATE POLICY "transactions_select_policy" ON "public"."transactions"
FOR SELECT TO authenticated
USING (
    -- Users can see their own transactions
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    OR
    -- Admins can see all transactions
    public.is_admin()
    OR
    -- POS users can see all transactions
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        AND role = 'pos'
    )
);

-- Create separate policies for other actions
CREATE POLICY "transactions_admin_all_policy" ON "public"."transactions"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- ORDERS TABLE
-- ====================
-- Remove duplicate order policies
DROP POLICY IF EXISTS "Users can view their own orders" ON "public"."orders";
DROP POLICY IF EXISTS "Admins can manage all orders" ON "public"."orders";

-- Create consolidated order policies
CREATE POLICY "orders_select_policy" ON "public"."orders"
FOR SELECT TO authenticated
USING (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    OR
    public.is_admin()
);

CREATE POLICY "orders_admin_manage_policy" ON "public"."orders"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Users can create their own orders
CREATE POLICY "orders_user_create_policy" ON "public"."orders"
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

-- Users can update their own pending orders
CREATE POLICY "orders_user_update_policy" ON "public"."orders"
FOR UPDATE TO authenticated
USING (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    AND status = 'pending'
)
WITH CHECK (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
);

-- ====================
-- ORDER ITEMS TABLE
-- ====================
-- Remove duplicate order items policies
DROP POLICY IF EXISTS "Users can view their own order items" ON "public"."order_items";
DROP POLICY IF EXISTS "Admins can manage all order items" ON "public"."order_items";

-- Create consolidated order items policies
CREATE POLICY "order_items_select_policy" ON "public"."order_items"
FOR SELECT TO authenticated
USING (
    (SELECT user_id FROM public.orders WHERE id = order_id) = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    OR
    public.is_admin()
);

CREATE POLICY "order_items_admin_manage_policy" ON "public"."order_items"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Users can create/update items for their own orders
CREATE POLICY "order_items_user_modify_policy" ON "public"."order_items"
FOR INSERT TO authenticated
WITH CHECK (
    (SELECT user_id FROM public.orders WHERE id = order_id) = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
);

-- ====================
-- PRODUCTS TABLE
-- ====================
-- Remove duplicate product policies
DROP POLICY IF EXISTS "Allow public read access to products" ON "public"."products";
DROP POLICY IF EXISTS "Allow admin full access to products" ON "public"."products";

-- Create consolidated product policies
CREATE POLICY "products_public_read_policy" ON "public"."products"
FOR SELECT
USING (true);  -- Public read access

CREATE POLICY "products_admin_manage_policy" ON "public"."products"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- PROFILES TABLE
-- ====================
-- Remove duplicate profile policies
DROP POLICY IF EXISTS "Allow storage service" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;

-- Create consolidated profile policies
CREATE POLICY "profiles_service_role_policy" ON public.profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "profiles_user_read_policy" ON public.profiles
FOR SELECT TO authenticated
USING (
    auth.uid() = auth_user_id
    OR
    public.is_admin()
);

CREATE POLICY "profiles_user_update_policy" ON public.profiles
FOR UPDATE TO authenticated
USING (auth.uid() = auth_user_id)
WITH CHECK (auth.uid() = auth_user_id);

CREATE POLICY "profiles_admin_manage_policy" ON public.profiles
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- STOCK TABLES
-- ====================
-- Remove any duplicate stock policies
DROP POLICY IF EXISTS "Allow authenticated read access to stock locations" ON "public"."stock_locations";
DROP POLICY IF EXISTS "Allow authenticated read access to stock levels" ON "public"."stock_levels";
DROP POLICY IF EXISTS "Allow authenticated read access to stock movements" ON "public"."stock_movements";
DROP POLICY IF EXISTS "Allow authenticated users to create stock movements" ON "public"."stock_movements";

-- Create consolidated stock policies
CREATE POLICY "stock_locations_read_policy" ON "public"."stock_locations"
FOR SELECT TO authenticated
USING (true);

CREATE POLICY "stock_levels_read_policy" ON "public"."stock_levels"
FOR SELECT TO authenticated
USING (true);

CREATE POLICY "stock_movements_read_policy" ON "public"."stock_movements"
FOR SELECT TO authenticated
USING (true);

CREATE POLICY "stock_movements_create_policy" ON "public"."stock_movements"
FOR INSERT TO authenticated
WITH CHECK (true);

-- Admin can manage stock
CREATE POLICY "stock_admin_manage_policy" ON "public"."stock_movements"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- USER PRODUCT PRICES TABLE
-- ====================
-- Remove duplicate policies
DROP POLICY IF EXISTS "Admin and POS users can manage custom prices" ON "public"."user_product_prices";
DROP POLICY IF EXISTS "Users can view own custom prices" ON "public"."user_product_prices";

-- Create consolidated policies
CREATE POLICY "user_product_prices_read_policy" ON "public"."user_product_prices"
FOR SELECT TO authenticated
USING (
    user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    OR
    public.is_admin()
    OR
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.auth_user_id = auth.uid() 
        AND profiles.role = 'pos'
    )
);

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
-- REVIEWS TABLE
-- ====================
-- Remove duplicate policies
DROP POLICY IF EXISTS "Anyone can view reviews" ON "public"."reviews";
DROP POLICY IF EXISTS "Users can create own reviews" ON "public"."reviews";

-- Create consolidated policies
CREATE POLICY "reviews_public_read_policy" ON "public"."reviews"
FOR SELECT
USING (true);  -- Anyone can read reviews

CREATE POLICY "reviews_user_create_policy" ON "public"."reviews"
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

CREATE POLICY "reviews_user_update_policy" ON "public"."reviews"
FOR UPDATE TO authenticated
USING (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()))
WITH CHECK (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

CREATE POLICY "reviews_admin_manage_policy" ON "public"."reviews"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ====================
-- SETTINGS TABLE
-- ====================
-- Remove duplicate policies
DROP POLICY IF EXISTS "Admins can read settings" ON public.settings;
DROP POLICY IF EXISTS "Admins can update settings" ON public.settings;
DROP POLICY IF EXISTS "Service role can access settings" ON public.settings;

-- Create consolidated policies
CREATE POLICY "settings_service_role_policy" ON public.settings
FOR ALL TO service_role
USING (true) 
WITH CHECK (true);

CREATE POLICY "settings_admin_manage_policy" ON public.settings
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin()); 