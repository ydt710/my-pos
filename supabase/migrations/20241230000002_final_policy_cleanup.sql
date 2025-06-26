-- =============================================
-- FINAL POLICY CLEANUP - Remove Remaining Duplicates
-- =============================================
-- This migration cleans up the remaining specific duplicate policies

-- ====================
-- REVIEWS TABLE - Remove old-style policy names
-- ====================
DROP POLICY IF EXISTS "Admin and POS can manage all reviews" ON "public"."reviews";
DROP POLICY IF EXISTS "Service role full access to reviews" ON "public"."reviews";
DROP POLICY IF EXISTS "Users can delete own reviews" ON "public"."reviews";

-- Only keep the new consolidated policies
-- (reviews_admin_manage_policy, reviews_user_create_policy, reviews_public_read_policy, reviews_user_update_policy)

-- ====================
-- SETTINGS TABLE - Remove old-style policy names
-- ====================
DROP POLICY IF EXISTS "Only admins can update settings" ON "public"."settings";
DROP POLICY IF EXISTS "Admins can insert settings" ON "public"."settings";
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."settings";
DROP POLICY IF EXISTS "Users can view settings" ON "public"."settings";

-- Only keep the new consolidated policies
-- (settings_service_role_policy, settings_admin_manage_policy)

-- ====================
-- STOCK MOVEMENTS TABLE - Remove old-style policy names
-- ====================
DROP POLICY IF EXISTS "Allow admins to manage stock movements" ON "public"."stock_movements";
DROP POLICY IF EXISTS "Allow users to update their own stock movements" ON "public"."stock_movements";

-- Only keep the new consolidated policies
-- (stock_admin_manage_policy, stock_movements_create_policy, stock_movements_read_policy)

-- ====================
-- USER PRODUCT PRICES TABLE - Remove old-style policy names
-- ====================
DROP POLICY IF EXISTS "Service role full access" ON "public"."user_product_prices";

-- Only keep the new consolidated policies
-- (user_product_prices_admin_pos_manage_policy, user_product_prices_read_policy)

-- ====================
-- PROFILES TABLE - This should be fine now (2 ALL policies for different roles)
-- ====================
-- profiles_admin_manage_policy (authenticated)
-- profiles_service_role_policy (service_role)
-- These are different roles, so they're not duplicates - this is correct 