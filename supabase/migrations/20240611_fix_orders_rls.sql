-- Drop old policies if they exist
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
DROP POLICY IF EXISTS "Users can create orders" ON orders;
DROP POLICY IF EXISTS "Users can update their own orders" ON orders;
DROP POLICY IF EXISTS "Admins can delete any order" ON orders;
DROP POLICY IF EXISTS "Users can delete their own orders" ON orders;

-- Allow users to view their own orders
CREATE POLICY "Users can view their own orders" ON orders
  FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to create orders
CREATE POLICY "Users can create orders" ON orders
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own orders
CREATE POLICY "Users can update their own orders" ON orders
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Allow admins (by JWT metadata) to delete any order
CREATE POLICY "Admins can delete any order" ON orders
  FOR DELETE
  USING ((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean = true);

-- Allow users to delete their own orders
CREATE POLICY "Users can delete their own orders" ON orders
  FOR DELETE
  USING (auth.uid() = user_id); 