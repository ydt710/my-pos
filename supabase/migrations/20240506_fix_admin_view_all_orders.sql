-- Drop existing policies
DROP POLICY IF EXISTS "Users can view orders" ON orders;
DROP POLICY IF EXISTS "Users can view order items" ON order_items;

-- Create updated policies that allow admin access to all orders
CREATE POLICY "Users can view orders"
    ON orders FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            auth.uid() = user_id OR 
            EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) OR
            guest_info IS NOT NULL
        )
    );

CREATE POLICY "Users can view order items"
    ON order_items FOR SELECT
    USING (
        order_id IN (
            SELECT id FROM orders WHERE 
                auth.role() = 'authenticated' AND (
                    user_id = auth.uid() OR 
                    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) OR
                    guest_info IS NOT NULL
                )
        )
    );

-- Ensure proper permissions
GRANT SELECT ON orders TO authenticated;
GRANT SELECT ON order_items TO authenticated; 