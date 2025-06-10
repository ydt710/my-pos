-- Create private storage buckets for signatures and ID images
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('signatures', 'signatures', false),
  ('id_images', 'id_images', false)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for the signatures bucket
CREATE POLICY "Users can upload their own signatures"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'signatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view their own signatures"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'signatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Set up RLS policies for the id_images bucket
CREATE POLICY "Users can upload their own ID images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'id_images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view their own ID images"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'id_images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow admins to view all files in both buckets
CREATE POLICY "Admins can view all signatures"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'signatures' AND
  ((auth.jwt() -> 'user_metadata')::jsonb ->> 'is_admin')::boolean = true
);

CREATE POLICY "Admins can view all ID images"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'id_images' AND
  ((auth.jwt() -> 'user_metadata')::jsonb ->> 'is_admin')::boolean = true
); 