-- Enable RLS on products table
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop old policies if they exist
DROP POLICY IF EXISTS "Allow all select" ON products;
DROP POLICY IF EXISTS "Admins can insert products" ON products;
DROP POLICY IF EXISTS "Admins can update products" ON products;
DROP POLICY IF EXISTS "Admins can delete products" ON products;

-- Allow all users to select products
CREATE POLICY "Allow all select" ON products
  FOR SELECT
  USING (true);

-- Allow only admins to insert products
CREATE POLICY "Admins can insert products" ON products
  FOR INSERT
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean = true);

-- Allow only admins to update products
CREATE POLICY "Admins can update products" ON products
  FOR UPDATE
  USING ((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean = true);

-- Allow only admins to delete products
CREATE POLICY "Admins can delete products" ON products
  FOR DELETE
  USING ((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean = true); 