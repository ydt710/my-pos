-- Drop the old foreign key constraint if it exists
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_user_id_fkey;

-- Add the correct foreign key constraint
ALTER TABLE orders
  ADD CONSTRAINT orders_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES profiles(id)
  ON DELETE SET NULL; 