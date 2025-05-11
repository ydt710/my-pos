-- Enable RLS on orders table
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

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

-- Allow admins to delete any order (assumes 'role' column in profiles)
CREATE POLICY "Admins can delete any order" ON orders
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  ); 