CREATE OR REPLACE FUNCTION is_current_user_admin_or_pos()
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
  is_admin_user BOOLEAN;
BEGIN
  SELECT role, is_admin
  INTO user_role, is_admin_user
  FROM public.profiles
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
  
  RETURN COALESCE(is_admin_user, FALSE) OR user_role = 'pos';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the old policy if it exists, using IF EXISTS to avoid errors
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- Create the new, more inclusive policy
CREATE POLICY "Admins and POS can view all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (is_current_user_admin_or_pos());

-- Ensure users can still view their own profile
-- It's good practice to be explicit. Let's make sure this policy is also in place.
-- This policy should already exist from a previous migration, so we will not attempt to create it again.
-- CREATE POLICY "Users can view their own profile"
-- ON public.profiles FOR SELECT
-- TO authenticated
-- USING (auth.uid() = auth_user_id); 