-- =============================================
-- FUNCTIONS AND RLS POLICIES
-- =============================================

-- =============================================
-- PART 1: CORE FUNCTIONS
-- =============================================

-- Function to check if the current user is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE auth_user_id = auth.uid() AND is_admin = true
  );
$$;

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (auth_user_id, email, display_name, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'display_name',
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (auth_user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user profile creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- =============================================
-- PART 2: RLS POLICIES
-- =============================================

-- Products policies
DROP POLICY IF EXISTS "Allow public read access to products" ON "public"."products";
CREATE POLICY "Allow public read access to products" ON "public"."products" 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin full access to products" ON "public"."products";
CREATE POLICY "Allow admin full access to products" ON "public"."products" 
FOR ALL USING (public.is_admin());

-- Profiles policies
DROP POLICY IF EXISTS "Allow storage service" ON public.profiles;
CREATE POLICY "Allow storage service" ON public.profiles
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
CREATE POLICY "Admins can manage all profiles" ON public.profiles
  FOR ALL USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Orders policies
DROP POLICY IF EXISTS "Users can view their own orders" ON "public"."orders";
CREATE POLICY "Users can view their own orders" ON "public"."orders" 
FOR SELECT USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all orders" ON "public"."orders";
CREATE POLICY "Admins can manage all orders" ON "public"."orders" 
FOR ALL USING (public.is_admin());

-- Transactions policies - CRITICAL FOR FIXING THE ERROR
DROP POLICY IF EXISTS "Allow users to view their own transactions" ON "public"."transactions";
CREATE POLICY "Allow users to view their own transactions" ON "public"."transactions"
FOR SELECT TO authenticated
USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Allow admins to manage all transactions" ON "public"."transactions";
CREATE POLICY "Allow admins to manage all transactions" ON "public"."transactions"
FOR ALL USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "POS users can view all transactions" ON "public"."transactions";
CREATE POLICY "POS users can view all transactions" ON "public"."transactions"
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        AND (is_admin = true OR role = 'pos')
    )
);

-- Settings policies
DROP POLICY IF EXISTS "Admins can read settings" ON public.settings;
CREATE POLICY "Admins can read settings" ON public.settings 
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND profiles.is_admin = true
  )
);

DROP POLICY IF EXISTS "Admins can update settings" ON public.settings;
CREATE POLICY "Admins can update settings" ON public.settings 
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND profiles.is_admin = true
  )
);

DROP POLICY IF EXISTS "Service role can access settings" ON public.settings;
CREATE POLICY "Service role can access settings" ON public.settings 
FOR ALL TO service_role
USING (true) WITH CHECK (true);

-- Landing page tables policies (public read, admin write)
DROP POLICY IF EXISTS "Allow public read access to hero" ON "public"."landing_hero";
CREATE POLICY "Allow public read access to hero" ON "public"."landing_hero"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage hero" ON "public"."landing_hero";
CREATE POLICY "Allow admin to manage hero" ON "public"."landing_hero"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Allow public read access to categories" ON "public"."landing_categories";
CREATE POLICY "Allow public read access to categories" ON "public"."landing_categories"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage categories" ON "public"."landing_categories";
CREATE POLICY "Allow admin to manage categories" ON "public"."landing_categories"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Allow public read access to stores" ON "public"."landing_stores";
CREATE POLICY "Allow public read access to stores" ON "public"."landing_stores"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage stores" ON "public"."landing_stores";
CREATE POLICY "Allow admin to manage stores" ON "public"."landing_stores"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Allow public read access to featured products" ON "public"."landing_featured_products";
CREATE POLICY "Allow public read access to featured products" ON "public"."landing_featured_products"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage featured products" ON "public"."landing_featured_products";
CREATE POLICY "Allow admin to manage featured products" ON "public"."landing_featured_products"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Allow public read access to testimonials" ON "public"."landing_testimonials";
CREATE POLICY "Allow public read access to testimonials" ON "public"."landing_testimonials"
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin to manage testimonials" ON "public"."landing_testimonials";
CREATE POLICY "Allow admin to manage testimonials" ON "public"."landing_testimonials"
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Stock locations/levels/movements policies
DROP POLICY IF EXISTS "Allow authenticated read access to stock locations" ON "public"."stock_locations";
CREATE POLICY "Allow authenticated read access to stock locations" ON "public"."stock_locations"
FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read access to stock levels" ON "public"."stock_levels";
CREATE POLICY "Allow authenticated read access to stock levels" ON "public"."stock_levels"
FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read access to stock movements" ON "public"."stock_movements";
CREATE POLICY "Allow authenticated read access to stock movements" ON "public"."stock_movements"
FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated users to create stock movements" ON "public"."stock_movements";
CREATE POLICY "Allow authenticated users to create stock movements" ON "public"."stock_movements"
FOR INSERT TO authenticated WITH CHECK (true);

-- Reviews policies
DROP POLICY IF EXISTS "Anyone can view reviews" ON "public"."reviews";
CREATE POLICY "Anyone can view reviews" ON "public"."reviews"
FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Users can create own reviews" ON "public"."reviews";
CREATE POLICY "Users can create own reviews" ON "public"."reviews"
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()));

-- Order items policies
DROP POLICY IF EXISTS "Users can view their own order items" ON "public"."order_items";
CREATE POLICY "Users can view their own order items" ON "public"."order_items" 
FOR SELECT USING (
  (SELECT user_id FROM public.orders WHERE id = order_id) = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
);

DROP POLICY IF EXISTS "Admins can manage all order items" ON "public"."order_items";
CREATE POLICY "Admins can manage all order items" ON "public"."order_items" 
FOR ALL USING (public.is_admin());

-- User product prices policies
DROP POLICY IF EXISTS "Admin and POS users can manage custom prices" ON "public"."user_product_prices";
CREATE POLICY "Admin and POS users can manage custom prices" ON "public"."user_product_prices"
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.auth_user_id = auth.uid() 
    AND (profiles.is_admin = true OR profiles.role = 'pos')
  )
);

DROP POLICY IF EXISTS "Users can view own custom prices" ON "public"."user_product_prices";
CREATE POLICY "Users can view own custom prices" ON "public"."user_product_prices"
FOR SELECT TO authenticated
USING (user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid()));

-- =============================================
-- PART 3: GRANTS
-- =============================================

-- Grant permissions to anon users for landing page
GRANT SELECT ON TABLE public.products TO anon;
GRANT SELECT ON TABLE public.landing_hero TO anon;
GRANT SELECT ON TABLE public.landing_categories TO anon;
GRANT SELECT ON TABLE public.landing_stores TO anon;
GRANT SELECT ON TABLE public.landing_featured_products TO anon;
GRANT SELECT ON TABLE public.landing_testimonials TO anon;

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.order_items TO authenticated;
GRANT SELECT ON TABLE public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.reviews TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.stock_locations TO authenticated;
GRANT SELECT ON TABLE public.stock_levels TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.stock_movements TO authenticated;
GRANT SELECT ON TABLE public.transactions TO authenticated;
GRANT SELECT ON TABLE public.user_product_prices TO authenticated;
GRANT SELECT ON public.user_balances TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.settings TO authenticated;
GRANT SELECT ON TABLE public.landing_hero TO authenticated;
GRANT SELECT ON TABLE public.landing_categories TO authenticated;
GRANT SELECT ON TABLE public.landing_stores TO authenticated;
GRANT SELECT ON TABLE public.landing_featured_products TO authenticated;
GRANT SELECT ON TABLE public.landing_testimonials TO authenticated;
GRANT ALL ON TABLE public.landing_hero TO authenticated;
GRANT ALL ON TABLE public.landing_categories TO authenticated;
GRANT ALL ON TABLE public.landing_stores TO authenticated;
GRANT ALL ON TABLE public.landing_featured_products TO authenticated;
GRANT ALL ON TABLE public.landing_testimonials TO authenticated;

-- Grant usage on sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT UPDATE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant permissions to service role
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Grant public view access
GRANT SELECT ON public.user_balances TO anon; 