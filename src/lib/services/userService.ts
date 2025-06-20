import { supabase } from '../supabase';

export async function makeUserAdmin(userId: string): Promise<boolean> {
  try {
    const { error } = await supabase
      .from('profiles')
      .update({ is_admin: true })
      .eq('auth_user_id', userId);
    if (error) {
      console.error('Error making user admin:', error);
      return false;
    }
    return true;
  } catch (err) {
    console.error('Unexpected error making user admin:', err);
    return false;
  }
} 