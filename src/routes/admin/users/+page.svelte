<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { fade } from 'svelte/transition';
  import { getUserBalance, getAllUserBalances } from '$lib/services/orderService';
  import { onDestroy } from 'svelte';
  import type { CreditLedgerEntry } from '$lib/types/ledger';

  interface User {
    id: string;
    email: string;
    created_at: string;
    is_admin?: boolean;
    role?: string;
    balance?: number;
    display_name?: string;
  }

  let users: User[] = [];
  let loading = true;
  let error: string | null = null;
  let success: string | null = null;
  let ledgerModalUser: User | null = null;
  let ledgerEntries: CreditLedgerEntry[] = [];
  let loadingLedger = false;
  let ledgerError: string | null = null;

  // Store balances for each user
  let userBalances: Record<string, number | null> = {};

  let showDeleteModal = false;
  let userToDelete: User | null = null;

  onMount(async () => {
    // Check if current user is admin
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser) {
      goto('/');
      return;
    }
    // Fetch profile for admin check
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin')
      .eq('auth_user_id', currentUser.id)
      .maybeSingle();
    if (!profile?.is_admin) {
      goto('/');
      return;
    }
    fetchUsers();
  });

  async function fetchUsers() {
    loading = true;
    error = null;
    try {
      // Check if user is authenticated and admin
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      if (!currentUser) {
        throw new Error('Not authenticated');
      }
      // FIX: Check admin status from profiles table, not from currentUser.is_admin
      const { data: profile } = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('auth_user_id', currentUser.id)
        .maybeSingle();
      if (!profile?.is_admin) {
        throw new Error('Not authorized - Admin access required');
      }

      // Fetch all profiles
      const { data: profilesData, error: profilesError } = await supabase
        .from('profiles')
        .select('*');
      if (profilesError) throw profilesError;

      // Sort by balance ascending (null treated as 0)
      users = profilesData
        .map(p => ({
          id: p.id,
          email: p.email,
          created_at: p.created_at,
          is_admin: p.is_admin,
          role: p.role,
          balance: p.balance ?? 0,
          display_name: p.display_name ?? ''
        }))
        .sort((a, b) => (a.balance ?? 0) - (b.balance ?? 0));
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
            is_admin: makeAdmin
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

  async function fetchAllUserBalances() {
    userBalances = await getAllUserBalances();
  }

  $: if (!loading && users.length > 0) {
    fetchAllUserBalances();
  }

  async function openLedgerModal(user: User) {
    ledgerModalUser = user;
    loadingLedger = true;
    ledgerError = null;
    const { data, error } = await supabase
      .from('credit_ledger')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: true });
    if (error) {
      ledgerError = 'Failed to load ledger entries.';
      ledgerEntries = [];
    } else {
      ledgerEntries = data || [];
    }
    loadingLedger = false;
  }

  function closeLedgerModal() {
    ledgerModalUser = null;
    ledgerEntries = [];
    ledgerError = null;
  }

  async function deleteUser(userId: string) {
    try {
      const { error } = await supabase.from('profiles').delete().eq('id', userId);
      if (error) throw error;
      users = users.filter(u => u.id !== userId);
      success = 'User deleted successfully';
      setTimeout(() => success = null, 3000);
    } catch (err) {
      console.error('Error deleting user:', err);
      error = 'Failed to delete user';
      setTimeout(() => error = null, 3000);
    }
  }

  function confirmDeleteUser(user: User) {
    userToDelete = user;
    showDeleteModal = true;
  }

  function cancelDeleteUser() {
    userToDelete = null;
    showDeleteModal = false;
  }

  async function handleDeleteUser() {
    if (userToDelete) {
      await deleteUser(userToDelete.id);
      userToDelete = null;
      showDeleteModal = false;
    }
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
      <div class="table-responsive">
        <table class="users-table">
          <thead>
            <tr>
              <th>Email</th>
              <th>Name</th>
              <th>Joined</th>
              <th>Role</th>
              <th>POS User</th>
              <th>Balance</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {#each users as user (user.id)}
              {@const balance = userBalances?.[user.id]}
              <tr>
                <td>{user.email}</td>
                <td>{user.display_name || '-'}</td>
                <td>{formatDate(user.created_at)}</td>
                <td>
                  <span class="role-badge" class:admin={user.is_admin}>
                    {user.is_admin ? 'Admin' : 'User'}
                  </span>
                </td>
                <td>{user.role === 'pos' ? 'Yes' : 'No'}</td>
                <td>
                  {#if typeof balance !== 'number'}
                    <span style="color: #666;">Loading...</span>
                  {:else if balance < 0}
                    <span style="color: #dc3545;">Debt: R{Math.abs(balance).toFixed(2)}</span>
                  {:else if balance > 0}
                    <span style="color: #28a745;">Credit: R{balance.toFixed(2)}</span>
                  {:else}
                    <span>R0.00</span>
                  {/if}
                  <button class="ledger-btn" on:click={() => openLedgerModal(user)} title="View Ledger">📄</button>
                </td>
                <td>
                  <button 
                    class="delete-user-btn"
                    on:click={() => confirmDeleteUser(user)}
                    aria-label="Delete user {user.email}"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  {/if}

  {#if ledgerModalUser}
    <div class="modal-backdrop" on:click={closeLedgerModal}>
      <div class="modal-content" on:click|stopPropagation>
        <h2>Ledger for {ledgerModalUser.email}</h2>
        {#if loadingLedger}
          <div>Loading ledger entries...</div>
        {:else if ledgerError}
          <div class="error-message">{ledgerError}</div>
        {:else if ledgerEntries.length === 0}
          <div>No ledger entries for this user.</div>
        {:else}
          <div class="ledger-table">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Amount</th>
                  <th>Order</th>
                  <th>Note</th>
                </tr>
              </thead>
              <tbody>
                {#each ledgerEntries as entry}
                  <tr>
                    <td>{new Date(entry.created_at).toLocaleString()}</td>
                    <td>{entry.type}</td>
                    <td style="color: {entry.amount < 0 ? '#dc3545' : entry.amount > 0 ? '#28a745' : '#333'};">
                      {entry.amount < 0 ? `-R${Math.abs(entry.amount).toFixed(2)}` : `R${entry.amount.toFixed(2)}`}
                    </td>
                    <td>{entry.order_id || '-'}</td>
                    <td>{entry.note}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
        <button class="close-btn" on:click={closeLedgerModal}>Close</button>
      </div>
    </div>
  {/if}

  {#if showDeleteModal && userToDelete}
    <div class="modal-backdrop" role="dialog" aria-modal="true" tabindex="-1" on:keydown={(e) => { if (e.key === 'Escape') cancelDeleteUser(); }}>
      <div class="modal-content" role="document" tabindex="0" on:click|stopPropagation>
        <h2 id="delete-modal-title">Confirm Delete</h2>
        <p>Are you sure you want to delete user <strong>{userToDelete.email}</strong>?</p>
        <div class="modal-actions">
          <button class="cancel-btn" on:click={cancelDeleteUser} aria-label="Cancel delete">Cancel</button>
          <button class="delete-user-btn" on:click={handleDeleteUser} aria-label="Confirm delete user">Delete</button>
        </div>
      </div>
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

  .table-responsive {
    width: 100%;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    margin-bottom: 1rem;
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

  @media (max-width: 800px) {
    .users-table-container {
      margin: 0 -1rem;
      border-radius: 0;
    }
    .table-responsive {
      width: 100%;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
      margin-bottom: 1rem;
    }
    .users-table {
      min-width: 700px;
      font-size: 0.95rem;
    }
    .users-table th,
    .users-table td {
      padding: 0.5rem;
    }
    .role-toggle-btn, .delete-user-btn {
      padding: 0.5rem 0.75rem;
      font-size: 1rem;
      width: 100%;
    }
  }

  .ledger-btn {
    background: none;
    border: none;
    font-size: 1.1em;
    margin-left: 0.5em;
    cursor: pointer;
    color: #007bff;
    transition: color 0.2s;
  }
  .ledger-btn:hover {
    color: #0056b3;
  }
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0,0,0,0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  .modal-content {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    max-width: 700px;
    width: 95vw;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    position: relative;
  }
  .close-btn {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: none;
    border: none;
    font-size: 1.5rem;
    color: #666;
    cursor: pointer;
    transition: color 0.2s;
  }
  .close-btn:hover {
    color: #333;
  }
  .ledger-table {
    overflow-x: auto;
    margin-top: 1rem;
  }
  .ledger-table table {
    width: 100%;
    border-collapse: collapse;
  }
  .ledger-table th, .ledger-table td {
    padding: 0.75rem;
    border-bottom: 1px solid #eee;
    text-align: left;
  }
  .ledger-table th {
    background: #f8f9fa;
    font-weight: 600;
    color: #333;
  }
  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
  }
  .delete-user-btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.875rem;
    background: #dc3545;
    color: white;
    transition: background 0.2s;
  }
  .delete-user-btn:hover {
    background: #c82333;
  }
  .modal-actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    margin-top: 2rem;
  }
  .cancel-btn {
    background: #e9ecef;
    color: #495057;
    border: none;
    border-radius: 4px;
    padding: 0.5rem 1rem;
    cursor: pointer;
    font-size: 0.875rem;
    transition: background 0.2s;
  }
  .cancel-btn:hover {
    background: #dee2e6;
  }
</style> 