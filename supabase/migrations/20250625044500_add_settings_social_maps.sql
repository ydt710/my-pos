-- Add Google Maps and social media fields to settings table
ALTER TABLE public.settings
ADD COLUMN IF NOT EXISTS google_maps_embed_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS facebook_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS instagram_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS twitter_url TEXT DEFAULT '';

-- Update RLS policy to include new fields
DROP POLICY IF EXISTS "Users can view settings" ON public.settings;
CREATE POLICY "Users can view settings" ON public.settings
  FOR SELECT
  USING (true);

-- Ensure only admins can update settings  
DROP POLICY IF EXISTS "Only admins can update settings" ON public.settings;
CREATE POLICY "Only admins can update settings" ON public.settings
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.auth_user_id = auth.uid() 
      AND profiles.is_admin = true
    )
  ); 