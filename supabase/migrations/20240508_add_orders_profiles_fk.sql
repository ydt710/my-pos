-- Add foreign key constraint between orders and profiles
ALTER TABLE orders
ADD CONSTRAINT orders_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES auth.users (id)
ON DELETE SET NULL; 