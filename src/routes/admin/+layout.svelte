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
    // Query profiles for is_admin
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin')
      .eq('auth_user_id', user.id)
      .maybeSingle();
    if (!profile?.is_admin) {
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
  <div class="loading">Loading...</div>
{:else if isAdmin}
  <AdminNav />
  <main class="admin-content">
    <slot />
  </main>
{/if}

<style>
  .admin-content {
    padding: 5rem 2rem 2rem;
    max-width: 1400px;
    margin: 0 auto;
  }

  .loading {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    font-size: 1.2rem;
    color: #666;
  }

  @media (max-width: 800px) {
    .admin-content {
      padding: 7rem 1rem 1rem;
    }
  }
</style> 