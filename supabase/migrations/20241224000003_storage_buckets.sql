-- =============================================
-- STORAGE BUCKETS SETUP
-- =============================================

-- Create storage buckets (idempotent due to ON CONFLICT)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('products', 'products', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp']),
  ('signatures', 'signatures', false, 1048576, ARRAY['image/png']),
  ('id_images', 'id_images', false, 5242880, ARRAY['image/png', 'image/jpeg']),
  ('contracts', 'contracts', false, 10485760, ARRAY['application/pdf']),
  ('signed.contracts', 'signed.contracts', false, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
CREATE POLICY "Allow public read access to product images" ON storage.objects 
FOR SELECT TO anon, authenticated 
USING (bucket_id = 'products');

DROP POLICY IF EXISTS "Allow admin to manage product images" ON storage.objects;
CREATE POLICY "Allow admin to manage product images" ON storage.objects 
FOR ALL 
USING (bucket_id = 'products' AND public.is_admin());

DROP POLICY IF EXISTS "Users can upload their own signatures" ON storage.objects;
CREATE POLICY "Users can upload their own signatures" ON storage.objects 
FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'signatures' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can view their own signatures" ON storage.objects;
CREATE POLICY "Users can view their own signatures" ON storage.objects 
FOR SELECT TO authenticated 
USING (bucket_id = 'signatures' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Admins can view all signatures" ON storage.objects;
CREATE POLICY "Admins can view all signatures" ON storage.objects 
FOR SELECT TO authenticated 
USING (bucket_id = 'signatures' AND public.is_admin());

DROP POLICY IF EXISTS "Users can upload their own ID images" ON storage.objects;
CREATE POLICY "Users can upload their own ID images" ON storage.objects 
FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'id_images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can view their own ID images" ON storage.objects;
CREATE POLICY "Users can view their own ID images" ON storage.objects 
FOR SELECT TO authenticated 
USING (bucket_id = 'id_images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Admins can view all ID images" ON storage.objects;
CREATE POLICY "Admins can view all ID images" ON storage.objects 
FOR SELECT TO authenticated 
USING (bucket_id = 'id_images' AND public.is_admin());

-- Contracts bucket policies
DROP POLICY IF EXISTS "Users can upload their own contracts" ON storage.objects;
CREATE POLICY "Users can upload their own contracts" ON storage.objects 
FOR INSERT TO authenticated 
WITH CHECK (
    bucket_id = 'contracts' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Users can view their own contracts" ON storage.objects;
CREATE POLICY "Users can view their own contracts" ON storage.objects 
FOR SELECT TO authenticated 
USING (
    bucket_id = 'contracts' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Admins can view all contracts" ON storage.objects;
CREATE POLICY "Admins can view all contracts" ON storage.objects 
FOR SELECT TO authenticated 
USING (
    bucket_id = 'contracts' AND 
    public.is_admin()
);

-- Signed contracts bucket policies (for backward compatibility)
DROP POLICY IF EXISTS "Users can upload signed contracts" ON storage.objects;
CREATE POLICY "Users can upload signed contracts" ON storage.objects 
FOR INSERT TO authenticated 
WITH CHECK (
    bucket_id = 'signed.contracts' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Users can view signed contracts" ON storage.objects;
CREATE POLICY "Users can view signed contracts" ON storage.objects 
FOR SELECT TO authenticated 
USING (
    bucket_id = 'signed.contracts' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Admins can view all signed contracts" ON storage.objects;
CREATE POLICY "Admins can view all signed contracts" ON storage.objects 
FOR SELECT TO authenticated 
USING (
    bucket_id = 'signed.contracts' AND 
    public.is_admin()
); 