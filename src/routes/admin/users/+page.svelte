<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { fade } from 'svelte/transition';

  interface AuthUser {
    id: string;
    email: string;
    created_at: string;
    raw_user_meta_data: {
      name?: string;
      is_admin?: boolean;
      [key: string]: any;
    };
  }

  interface User {
    id: string;
    email: string;
    created_at: string;
    user_metadata: {
      name?: string;
      is_admin?: boolean;
    };
    is_admin?: boolean;
  }

  let users: User[] = [];
  let loading = true;
  let error: string | null = null;
  let success: string | null = null;

  onMount(async () => {
    // Check if current user is admin
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser?.user_metadata?.is_admin) {
      goto('/');
      return;
    }
    fetchUsers();
  });

  async function fetchUsers() {
    loading = true;
    error = null;
    try {
      // First check if user is authenticated and admin
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      if (!currentUser) {
        throw new Error('Not authenticated');
      }
      if (!currentUser.user_metadata?.is_admin) {
        throw new Error('Not authorized - Admin access required');
      }

      // Fetch users from auth.users to get metadata
      const { data: authData, error: authError } = await supabase.rpc('get_users_with_metadata');
      if (authError) {
        console.error('RPC Error:', authError);
        throw new Error(authError.message || 'Failed to fetch users');
      }

      // Fetch profiles to get additional info
      const { data: profilesData, error: profilesError } = await supabase
        .from('profiles')
        .select('*');
      if (profilesError) throw profilesError;

      // Merge the data
      users = (authData as AuthUser[]).map(authUser => {
        const profile = profilesData.find(p => p.id === authUser.id);
        return {
          id: authUser.id,
          email: authUser.email,
          created_at: authUser.created_at,
          user_metadata: {
            name: profile?.display_name || authUser.raw_user_meta_data?.name,
            is_admin: authUser.raw_user_meta_data?.is_admin || profile?.is_admin
          },
          is_admin: authUser.raw_user_meta_data?.is_admin || profile?.is_admin
        };
      });
    } catch (err) {
      console.error('Error fetching users:', err);
      error = err instanceof Error ? err.message : 'Failed to load users';
    } finally {
      loading = false;
    }
  }

  async function toggleAdmin(userId: string, makeAdmin: boolean) {
    try {
      // 1. Update auth metadata using RPC function
      const { error: rpcError } = await supabase.rpc('update_user_admin_status', {
        user_id: userId,
        is_admin: makeAdmin
      });
      if (rpcError) throw rpcError;

      // 2. Update profiles table
      const { error: profileError } = await supabase
        .from('profiles')
        .update({ is_admin: makeAdmin })
        .eq('id', userId);
      if (profileError) throw profileError;

      // Update local state
      users = users.map(user => {
        if (user.id === userId) {
          return {
            ...user,
            is_admin: makeAdmin,
            user_metadata: {
              ...user.user_metadata,
              is_admin: makeAdmin
            }
          };
        }
        return user;
      });

      success = `User ${makeAdmin ? 'promoted to' : 'removed from'} admin successfully`;
      setTimeout(() => success = null, 3000);
    } catch (err) {
      console.error('Error updating user:', err);
      error = 'Failed to update user role';
      setTimeout(() => error = null, 3000);
    }
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
</script>

<div class="users-page" in:fade>
  <header class="page-header">
    <h1>User Management</h1>
  </header>

  {#if error}
    <div class="alert error" role="alert" transition:fade>{error}</div>
  {/if}

  {#if success}
    <div class="alert success" role="alert" transition:fade>{success}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading users...</div>
  {:else if users.length === 0}
    <div class="no-users">No users found</div>
  {:else}
    <div class="users-table-container">
      <table class="users-table">
        <thead>
          <tr>
            <th>Email</th>
            <th>Name</th>
            <th>Joined</th>
            <th>Role</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each users as user (user.id)}
            <tr>
              <td>{user.email}</td>
              <td>{user.user_metadata?.name || '-'}</td>
              <td>{formatDate(user.created_at)}</td>
              <td>
                <span class="role-badge" class:admin={user.is_admin}>
                  {user.is_admin ? 'Admin' : 'User'}
                </span>
              </td>
              <td>
                <button 
                  class="role-toggle-btn"
                  class:make-admin={!user.is_admin}
                  class:remove-admin={user.is_admin}
                  on:click={() => toggleAdmin(user.id, !user.is_admin)}
                >
                  {user.is_admin ? 'Remove Admin' : 'Make Admin'}
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .users-page {
    padding: 1rem;
  }

  .page-header {
    margin-bottom: 2rem;
  }

  .page-header h1 {
    margin: 0;
    font-size: 2rem;
    color: #333;
  }

  .alert {
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
  }

  .error {
    background: #f8d7da;
    color: #721c24;
  }

  .success {
    background: #d4edda;
    color: #155724;
  }

  .loading {
    text-align: center;
    padding: 2rem;
    color: #6c757d;
  }

  .no-users {
    text-align: center;
    padding: 2rem;
    color: #6c757d;
    background: #f8f9fa;
    border-radius: 4px;
  }

  .users-table-container {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    overflow: hidden;
  }

  .users-table {
    width: 100%;
    border-collapse: collapse;
  }

  .users-table th,
  .users-table td {
    padding: 1rem;
    text-align: left;
    border-bottom: 1px solid #dee2e6;
  }

  .users-table th {
    background: #f8f9fa;
    font-weight: 600;
    color: #495057;
  }

  .users-table tr:hover {
    background: #f8f9fa;
  }

  .role-badge {
    display: inline-block;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.875rem;
    background: #e9ecef;
    color: #495057;
  }

  .role-badge.admin {
    background: #cce5ff;
    color: #004085;
  }

  .role-toggle-btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.875rem;
    transition: all 0.2s;
  }

  .role-toggle-btn.make-admin {
    background: #28a745;
    color: white;
  }

  .role-toggle-btn.remove-admin {
    background: #dc3545;
    color: white;
  }

  .role-toggle-btn.make-admin:hover {
    background: #218838;
  }

  .role-toggle-btn.remove-admin:hover {
    background: #c82333;
  }

  @media (max-width: 768px) {
    .users-table-container {
      margin: 0 -1rem;
      border-radius: 0;
    }

    .users-table th,
    .users-table td {
      padding: 0.75rem;
    }

    .role-toggle-btn {
      padding: 0.375rem 0.75rem;
    }
  }
</style> 