-- Create admin check function
create or replace function auth.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'is_admin',
    'false'
  )::boolean
$$;

-- Create function to get users with metadata
create or replace function public.get_users_with_metadata()
returns table (
    id uuid,
    email text,
    created_at timestamptz,
    raw_user_meta_data jsonb
)
security definer
set search_path = public
language plpgsql
as $$
begin
    -- Check if user is admin
    if not auth.is_admin() then
        raise exception 'Only administrators can view user metadata';
    end if;

    return query
    select 
        au.id,
        au.email::text,
        au.created_at,
        au.raw_user_meta_data
    from auth.users au
    order by au.created_at desc;
end;
$$;

-- Create function to update user admin status
create or replace function public.update_user_admin_status(user_id uuid, is_admin boolean)
returns void
security definer
set search_path = public
language plpgsql
as $$
declare
    current_metadata jsonb;
begin
    -- Check if user is admin
    if not auth.is_admin() then
        raise exception 'Only administrators can update user roles';
    end if;

    -- Get current metadata
    select raw_user_meta_data into current_metadata
    from auth.users
    where id = user_id;

    -- Update the metadata
    update auth.users
    set raw_user_meta_data = 
        case 
            when current_metadata is null then 
                jsonb_build_object('is_admin', is_admin)
            else
                current_metadata || jsonb_build_object('is_admin', is_admin)
        end
    where id = user_id;

    -- Also update the profiles table to keep them in sync
    update auth.users
    set raw_user_meta_data = raw_user_meta_data || jsonb_build_object('is_admin', is_admin)
    where id = user_id;

    update public.profiles
    set is_admin = is_admin
    where id = user_id;
end;
$$;

-- Drop existing grants if they exist
revoke execute on function public.get_users_with_metadata from authenticated;
revoke execute on function public.update_user_admin_status from authenticated;
revoke execute on function auth.is_admin from authenticated;

-- Grant execute permission to authenticated users
grant execute on function public.get_users_with_metadata to authenticated;
grant execute on function public.update_user_admin_status to authenticated;
grant execute on function auth.is_admin to authenticated; 