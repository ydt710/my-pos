import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

// Use environment variables with fallbacks
const supabaseUrl = PUBLIC_SUPABASE_URL || 'https://wglybohfygczpapjxwwz.supabase.co';
const supabaseAnonKey = PUBLIC_SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnbHlib2hmeWdjenBhcGp4d3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYyMDI2OTYsImV4cCI6MjA2MTc3ODY5Nn0.F9Ja7Npo2aj-1EzgmG275aF_nkm6BvY7MprqQKhpFp0";

if (browser) {
  const isLocal = supabaseUrl.includes('127.0.0.1') || supabaseUrl.includes('localhost');
  const currentHost = window.location.host;
  
  if (isLocal) {
    console.log('🔧 Supabase: Using LOCAL development database');
    console.log('📍 Database URL:', supabaseUrl);
    console.log('🌐 Accessing from:', currentHost);
    
    // Warn if accessing from network IP but using localhost database
    if (!currentHost.includes('localhost') && !currentHost.includes('127.0.0.1')) {
      console.warn('⚠️  WARNING: You are accessing from a network IP (' + currentHost + ') but using a localhost database.');
      console.warn('   Other devices cannot access localhost database. Consider:');
      console.warn('   1. Switch to remote database in .env.local');
      console.warn('   2. Use ngrok for tunneling');
    }
  } else {
    console.log('🌐 Supabase: Using PRODUCTION database');
    console.log('📍 Database URL:', supabaseUrl);
    console.log('✅ Network access: Available from any device');
  }
}

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

// Helper function to test database connection
export async function testDatabaseConnection() {
  try {
    const { data, error } = await supabase
      .from('landing_hero')
      .select('title')
      .limit(1)
      .maybeSingle();
    
    if (error) {
      console.error('Database connection test failed:', error);
      return { success: false, error: error.message };
    }
    
    console.log('✅ Database connection successful');
    return { success: true, data };
  } catch (err) {
    console.error('Database connection test error:', err);
    return { success: false, error: err instanceof Error ? err.message : 'Unknown error' };
  }
}