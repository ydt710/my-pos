-- Add debt and credit columns to profiles if they do not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'debt') THEN
        ALTER TABLE profiles ADD COLUMN debt NUMERIC(12,2) DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'credit') THEN
        ALTER TABLE profiles ADD COLUMN credit NUMERIC(12,2) DEFAULT 0;
    END IF;
END $$;

-- Drop the 'debt' column and rename 'credit' to 'balance' in the profiles table
ALTER TABLE profiles DROP COLUMN IF EXISTS debt;
ALTER TABLE profiles RENAME COLUMN credit TO balance; 