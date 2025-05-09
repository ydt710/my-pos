-- Drop existing policies
DROP POLICY IF EXISTS "Users can view orders" ON orders;
DROP POLICY IF EXISTS "Users can view order items" ON order_items;
DROP POLICY IF EXISTS "Users can insert orders" ON orders;
DROP POLICY IF EXISTS "Users can insert order items" ON order_items;

-- Create updated policies for viewing orders
CREATE POLICY "Users can view orders"
    ON orders FOR SELECT
    USING (true);  -- Allow all authenticated users to view all orders

-- Create updated policies for inserting orders
CREATE POLICY "Users can insert orders"
    ON orders FOR INSERT
    WITH CHECK (true);  -- Allow all users to insert orders

-- Create updated policies for viewing order items
CREATE POLICY "Users can view order items"
    ON order_items FOR SELECT
    USING (true);  -- Allow all authenticated users to view all order items

-- Create updated policies for inserting order items
CREATE POLICY "Users can insert order items"
    ON order_items FOR INSERT
    WITH CHECK (true);  -- Allow all users to insert order items

-- Ensure proper permissions
GRANT SELECT, INSERT ON orders TO anon;
GRANT SELECT, INSERT ON order_items TO anon;
GRANT SELECT, INSERT ON orders TO authenticated;
GRANT SELECT, INSERT ON order_items TO authenticated; 