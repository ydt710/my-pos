-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own orders" ON orders;
DROP POLICY IF EXISTS "Users can view own order items" ON order_items;
DROP POLICY IF EXISTS "Users can insert orders" ON orders;
DROP POLICY IF EXISTS "Users can insert order items" ON order_items;

-- Create updated policies that properly handle guest orders
CREATE POLICY "Users can view own orders"
    ON orders FOR SELECT
    USING (
        (auth.role() = 'authenticated' AND auth.uid() = user_id) OR 
        (auth.role() = 'anon' AND guest_info IS NOT NULL) OR
        (guest_info->>'email' IS NOT NULL AND guest_info->>'email' = coalesce(current_setting('request.jwt.claims', true)::json->>'email', ''))
    );

CREATE POLICY "Users can insert orders"
    ON orders FOR INSERT
    WITH CHECK (
        (auth.role() = 'authenticated' AND auth.uid() = user_id) OR 
        (auth.role() = 'anon' AND guest_info IS NOT NULL AND user_id IS NULL)
    );

CREATE POLICY "Users can view own order items"
    ON order_items FOR SELECT
    USING (
        order_id IN (
            SELECT id FROM orders WHERE 
                (auth.role() = 'authenticated' AND user_id = auth.uid()) OR
                (auth.role() = 'anon' AND guest_info IS NOT NULL) OR
                (guest_info->>'email' IS NOT NULL AND guest_info->>'email' = coalesce(current_setting('request.jwt.claims', true)::json->>'email', ''))
        )
    );

CREATE POLICY "Users can insert order items"
    ON order_items FOR INSERT
    WITH CHECK (
        order_id IN (
            SELECT id FROM orders WHERE 
                (auth.role() = 'authenticated' AND user_id = auth.uid()) OR
                (auth.role() = 'anon' AND guest_info IS NOT NULL AND user_id IS NULL)
        )
    );

-- Ensure proper permissions for anonymous users
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT, INSERT ON orders TO anon;
GRANT SELECT, INSERT ON order_items TO anon;
GRANT SELECT ON products TO anon; 