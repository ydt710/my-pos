-- Add order_number column to orders table
ALTER TABLE orders ADD COLUMN order_number TEXT;

-- Create a unique index on order_number
CREATE UNIQUE INDEX idx_orders_order_number ON orders(order_number);

-- Update existing orders with a generated order number based on their creation timestamp
UPDATE orders
SET order_number = to_char(created_at::timestamp, 'YYMMDD') || 
                   to_char(created_at::timestamp, 'HH24MISS')
WHERE order_number IS NULL; 