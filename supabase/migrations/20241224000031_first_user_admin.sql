-- Drop function and trigger if they exist
DROP FUNCTION IF EXISTS public.set_first_user_admin() CASCADE;
DROP TRIGGER IF EXISTS trg_set_first_user_admin ON public.profiles;

-- Create the trigger function
CREATE OR REPLACE FUNCTION public.set_first_user_admin()
RETURNS TRIGGER AS $$
BEGIN
  -- If this is the first profile, make it admin and pos
  IF (SELECT COUNT(*) FROM public.profiles) = 1 THEN
    UPDATE public.profiles
    SET is_admin = TRUE, role = 'pos'
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trg_set_first_user_admin
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_first_user_admin();