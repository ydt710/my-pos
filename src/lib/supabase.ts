import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';

const supabaseUrl = 'https://wglybohfygczpapjxwwz.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnbHlib2hmeWdjenBhcGp4d3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYyMDI2OTYsImV4cCI6MjA2MTc3ODY5Nn0.F9Ja7Npo2aj-1EzgmG275aF_nkm6BvY7MprqQKhpFp0';

// Create a single client for all operations with session handling
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: browser ? window.localStorage : undefined
  }
});

// Only set up auth state listener in the browser
if (browser) {
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED') {
      // Handle auth state changes if needed
      console.log('Auth state changed:', event);
    }
  });
}

// Function to make a user an admin
export async function makeUserAdmin(userId: string) {
  const { error } = await supabase
    .from('profiles')
    .update({ is_admin: true })
    .eq('auth_user_id', userId);
  if (error) {
    console.error('Error making user admin:', error);
    return false;
  }
  return true;
}

// Helper function to check if the current session is valid
export async function checkSession() {
  const { data: { session }, error } = await supabase.auth.getSession();
  if (error || !session) {
    return false;
  }
  return true;
}

// Helper function to refresh the session
export async function refreshSession() {
  const { data: { session }, error } = await supabase.auth.refreshSession();
  if (error || !session) {
    return false;
  }
  return true;
}