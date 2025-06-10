CREATE UNIQUE INDEX IF NOT EXISTS profiles_auth_user_id_key ON public.profiles USING btree (auth_user_id);

ALTER TABLE public.profiles ADD CONSTRAINT profiles_auth_user_id_key UNIQUE USING INDEX profiles_auth_user_id_key;

COMMENT ON CONSTRAINT profiles_auth_user_id_key ON public.profiles IS 'Ensures one profile per authenticated user.'; 