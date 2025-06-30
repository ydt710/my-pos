-- =============================================
-- MIGRATION: Fix stock_levels RLS policies
-- =============================================
-- Add missing INSERT, UPDATE, and DELETE policies for stock_levels table
-- =============================================

-- Add INSERT policy for stock_levels (allow authenticated users)
CREATE POLICY "stock_levels_insert_policy" ON "public"."stock_levels"
FOR INSERT TO authenticated
WITH CHECK (true);

-- Add UPDATE policy for stock_levels (allow authenticated users) 
CREATE POLICY "stock_levels_update_policy" ON "public"."stock_levels"
FOR UPDATE TO authenticated
USING (true)
WITH CHECK (true);

-- Add DELETE policy for stock_levels (allow admins only)
CREATE POLICY "stock_levels_delete_policy" ON "public"."stock_levels"
FOR DELETE TO authenticated
USING (public.is_admin());

-- Add service role full access policy (needed for functions)
CREATE POLICY "stock_levels_service_role_policy" ON "public"."stock_levels"
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Also add admin management policy for completeness
CREATE POLICY "stock_levels_admin_manage_policy" ON "public"."stock_levels"
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin()); 