-- Add signature and ID image URL columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS signature_url TEXT,
ADD COLUMN IF NOT EXISTS id_image_url TEXT;

-- Add comments to explain the columns
COMMENT ON COLUMN profiles.signature_url IS 'URL to the user''s signature image stored in the signatures bucket';
COMMENT ON COLUMN profiles.id_image_url IS 'URL to the user''s ID or driver''s license image stored in the id_images bucket'; 