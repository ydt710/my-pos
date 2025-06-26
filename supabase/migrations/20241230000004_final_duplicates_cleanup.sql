-- =============================================
-- FINAL DUPLICATES CLEANUP
-- =============================================
-- Remove remaining duplicate policies with old naming conventions

-- Settings table - remove old policy names
DROP POLICY IF EXISTS "settings_admin_manage_policy" ON "public"."settings";
DROP POLICY IF EXISTS "settings_service_role_policy" ON "public"."settings";

-- Stock tables - remove old policy names  
DROP POLICY IF EXISTS "stock_levels_read_policy" ON "public"."stock_levels";
DROP POLICY IF EXISTS "stock_locations_read_policy" ON "public"."stock_locations";

-- Remove any other legacy policies that might still exist
DROP POLICY IF EXISTS "Allow authenticated read access to stock levels" ON "public"."stock_levels";
DROP POLICY IF EXISTS "Allow authenticated read access to stock locations" ON "public"."stock_locations"; 