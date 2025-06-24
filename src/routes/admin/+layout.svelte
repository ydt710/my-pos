<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import AdminNav from '$lib/components/AdminNav.svelte';
  import { checkSession, refreshSession } from '$lib/supabase';

  let isAdmin = false;
  let loading = true;

  async function checkAdminAccess() {
    // First check if we have a valid session
    const hasValidSession = await checkSession();
    if (!hasValidSession) {
      // Try to refresh the session
      const refreshed = await refreshSession();
      if (!refreshed) {
        goto('/login');
        return false;
      }
    }

    // Now check if the user is an admin
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      goto('/login');
      return false;
    }
    // Query profiles for is_admin or POS role
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin, role')
      .eq('auth_user_id', user.id)
      .maybeSingle();
    if (!profile?.is_admin && profile?.role !== 'pos') {
      goto('/');
      return false;
    }
    return true;
  }

  onMount(async () => {
    try {
      isAdmin = await checkAdminAccess();
    } finally {
      loading = false;
    }
  });
</script>

{#if loading}
  <div class="text-center" style="min-height: 100vh; display: flex; align-items: center; justify-content: center;">
    <div>
      <div class="spinner-large"></div>
      <p class="neon-text-cyan mt-2">Loading...</p>
    </div>
  </div>
{:else if isAdmin}
  <AdminNav />
  <main class="admin-layout-main">
    <slot />
  </main>
{/if}

<style>
  .admin-layout-main {
    min-height: 100vh;
    background: transparent;
  }
</style> 