CREATE OR REPLACE FUNCTION search_all_users(search_term TEXT)
RETURNS TABLE (id uuid, display_name TEXT, email TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.display_name, p.email
    FROM public.profiles p
    WHERE (p.display_name ILIKE '%' || search_term || '%'
       OR p.email ILIKE '%' || search_term || '%')
    LIMIT 10;
END;
$$; 