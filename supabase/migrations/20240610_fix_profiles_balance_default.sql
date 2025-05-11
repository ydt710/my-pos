ALTER TABLE profiles ALTER COLUMN balance SET DEFAULT 0;
UPDATE profiles SET balance = 0 WHERE balance IS NULL; 