-- =============================================
-- EXPORT SCRIPT 07d: LANDING PAGE RLS POLICIES
-- =============================================
-- Run this script after 07c_rls_business.sql.
-- This script creates RLS policies for landing page tables.
-- =============================================

-- Enable RLS on landing page tables
ALTER TABLE "public"."landing_hero" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_stores" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_featured_products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."landing_testimonials" ENABLE ROW LEVEL SECURITY;

-- Policies for: public.landing_hero
DROP POLICY IF EXISTS "Allow public read access to hero" ON "public"."landing_hero";
CREATE POLICY "Allow public read access to hero" ON "public"."landing_hero"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage hero" ON "public"."landing_hero";
CREATE POLICY "Allow admin to manage hero" ON "public"."landing_hero"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policies for: public.landing_categories
DROP POLICY IF EXISTS "Allow public read access to categories" ON "public"."landing_categories";
CREATE POLICY "Allow public read access to categories" ON "public"."landing_categories"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage categories" ON "public"."landing_categories";
CREATE POLICY "Allow admin to manage categories" ON "public"."landing_categories"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policies for: public.landing_stores
DROP POLICY IF EXISTS "Allow public read access to stores" ON "public"."landing_stores";
CREATE POLICY "Allow public read access to stores" ON "public"."landing_stores"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage stores" ON "public"."landing_stores";
CREATE POLICY "Allow admin to manage stores" ON "public"."landing_stores"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policies for: public.landing_featured_products
DROP POLICY IF EXISTS "Allow public read access to featured products" ON "public"."landing_featured_products";
CREATE POLICY "Allow public read access to featured products" ON "public"."landing_featured_products"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage featured products" ON "public"."landing_featured_products";
CREATE POLICY "Allow admin to manage featured products" ON "public"."landing_featured_products"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Policies for: public.landing_testimonials
DROP POLICY IF EXISTS "Allow public read access to testimonials" ON "public"."landing_testimonials";
CREATE POLICY "Allow public read access to testimonials" ON "public"."landing_testimonials"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage testimonials" ON "public"."landing_testimonials";
CREATE POLICY "Allow admin to manage testimonials" ON "public"."landing_testimonials"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin()); 