import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wglybohfygczpapjxwwz.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnbHlib2hmeWdjenBhcGp4d3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYyMDI2OTYsImV4cCI6MjA2MTc3ODY5Nn0.F9Ja7Npo2aj-1EzgmG275aF_nkm6BvY7MprqQKhpFp0';

// Create a single client for all operations
export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Function to make a user an admin
export async function makeUserAdmin(userId: string) {
  const { error } = await supabase.auth.admin.updateUserById(
    userId,
    { user_metadata: { is_admin: true } }
  );
  
  if (error) {
    console.error('Error making user admin:', error);
    return false;
  }
  return true;
}