<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { fade } from 'svelte/transition';
  import { getUserBalance } from '$lib/services/orderService';
  import { onDestroy } from 'svelte';
  import type { Transaction } from '$lib/types/ledger';
  import { debounce } from '$lib/utils';
  import StarryBackground from '$lib/components/StarryBackground.svelte';

  interface User {
    id: string;
    email: string;
    created_at: string;
    is_admin?: boolean;
    role?: string;
    display_name?: string;
  }

  let users: User[] = [];
  let loading = true;
  let error: string | null = null;
  let success: string | null = null;
  let ledgerModalUser: User | null = null;
  let ledgerEntries: Transaction[] = [];
  let loadingLedger = false;
  let ledgerError: string | null = null;

  // Store balances for each user
  let userBalances: { [key: string]: number } = {};

  let showDeleteModal = false;
  let userToDelete: User | null = null;

  let selectedUser: User | null = null;
  let userOrders: any[] = [];
  let userOrdersLoading = false;
  let userOrdersError: string | null = null;
  let userLedger: any[] = [];
  let userLedgerLoading = false;
  let userLedgerError: string | null = null;
  let userStats: { totalOrders: number; totalSpent: number; debt: number } = { totalOrders: 0, totalSpent: 0, debt: 0 };
  let contractUrl: string | null = null;

  let editingBalanceUserId: string | null = null;
  let adjustmentAmount: number | null = null;
  let adjustmentNote: string = '';

  let searchTerm = '';

  // Debounced search
  const handleSearchInput = debounce(async (value: string) => {
    await fetchUsers(value);
  }, 400);

  function onSearch(event: Event) {
    const target = event.target as HTMLInputElement;
    searchTerm = target.value;
    handleSearchInput(searchTerm);
  }

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

  async function fetchUsers(query = '') {
    loading = true;
    error = null;
    let filter = query ? `or=(display_name.ilike.%${query}%,email.ilike.%${query}%)` : '';
    let url = filter
      ? `/rest/v1/profiles?select=id,display_name,email,created_at,is_admin,role&${filter}&limit=50`
      : `/rest/v1/profiles?select=id,display_name,email,created_at,is_admin,role&limit=50`;
    try {
      const { data, error: fetchError } = await supabase
        .from('profiles')
        .select('id, display_name, email, created_at, is_admin, role')
        .ilike('display_name', `%${query}%`)
        .limit(50);
      if (fetchError) throw fetchError;
      users = data || [];
      await fetchAllUserBalances();
    } catch (err: any) {
      error = err?.message || 'Failed to fetch users.';
    } finally {
      loading = false;
    }
  }

  async function fetchAllUserBalances() {
    if (!users.length) return;
    const promises = users.map(user => getUserBalance(user.id));
    const results = await Promise.all(promises);
    userBalances = users.reduce<{ [key: string]: number }>((acc, user, i) => {
      acc[user.id] = results[i];
      return acc;
    }, {});
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

  function formatCurrency(value: number) {
    return `R${value.toFixed(2)}`;
  }

  function formatDate(dateStr: string) {
    return new Date(dateStr).toLocaleString();
  }

  function resetBalanceEditor() {
    editingBalanceUserId = null;
    adjustmentAmount = null;
    adjustmentNote = '';
  }

  async function openLedgerModal(user: User) {
    ledgerModalUser = user;
    loadingLedger = true;
    ledgerError = null;
    const { data, error } = await supabase
      .from('transactions')
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

  async function openUserDetail(user: User) {
    selectedUser = user;
    userOrdersLoading = true;
    userOrdersError = null;
    userLedgerLoading = true;
    userLedgerError = null;
    userOrders = [];
    userLedger = [];
    userStats = { totalOrders: 0, totalSpent: 0, debt: 0 };
    contractUrl = null;
    try {
      // Fetch orders for this user
      const { data: orders, error: ordersError } = await supabase
        .from('orders')
        .select('*, order_items(*, products(name))')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });
      if (ordersError) {
        userOrdersError = 'Failed to load orders.';
      } else {
        userOrders = orders || [];
        userStats.totalOrders = userOrders.length;
        userStats.totalSpent = userOrders.reduce((sum, o) => sum + (o.total || 0), 0);
      }
      // Fetch ledger for this user
      const { data: ledger, error: ledgerError } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });
      if (ledgerError) {
        userLedgerError = 'Failed to load ledger.';
      } else {
        userLedger = ledger || [];
        userStats.debt = userLedger.reduce((sum, e) => sum + (e.balance_amount || 0), 0);
      }
      // Fetch contract URL from profiles
      const { data: profile } = await supabase
        .from('profiles')
        .select('signed_contract_url')
        .eq('id', user.id)
        .maybeSingle();
      contractUrl = profile?.signed_contract_url || null;
    } catch (err) {
      userOrdersError = 'Failed to load user details.';
      userLedgerError = 'Failed to load user details.';
    } finally {
      userOrdersLoading = false;
      userLedgerLoading = false;
    }
  }

  function closeUserDetail() {
    selectedUser = null;
    userOrders = [];
    userLedger = [];
    userStats = { totalOrders: 0, totalSpent: 0, debt: 0 };
    contractUrl = null;
    adjustmentAmount = null;
    adjustmentNote = '';
  }

  async function downloadContract() {
    if (!contractUrl) return;
    const { data, error } = await supabase.storage
      .from('signed.contracts')
      .createSignedUrl(contractUrl, 600);
    if (data && data.signedUrl) {
      window.open(data.signedUrl, '_blank');
    } else {
      alert('Could not generate download link.');
    }
  }

  async function handleBalanceAdjustment(user: User, isDebt: boolean) {
    if (!adjustmentAmount) {
      error = 'Please enter an amount.';
      setTimeout(() => error = null, 3000);
      return;
    }
    const amount = isDebt ? -Math.abs(adjustmentAmount) : Math.abs(adjustmentAmount);
    const note = adjustmentNote || `Admin ${isDebt ? 'Debt' : 'Credit'} Adjustment`;
    
    const { error: rpcError } = await supabase.rpc('admin_adjust_balance', {
      p_user_id: user.id,
      p_amount: amount,
      p_note: note
    });

    if (rpcError) {
      error = 'Failed to adjust balance: ' + rpcError.message;
      setTimeout(() => error = null, 3000);
      return;
    }
    success = 'Balance updated!';
    setTimeout(() => success = null, 3000);
    
    // Refresh data
    await fetchAllUserBalances();
    await openUserDetail(user);

    adjustmentAmount = null;
    adjustmentNote = '';
  }
</script>

<StarryBackground />

<main class="admin-main">
  <div class="admin-container">
    <div class="admin-header">
      <h1 class="neon-text-cyan">User Management</h1>
      <input placeholder="Search users…" value={searchTerm} on:input={onSearch} class="form-control" style="max-width: 300px;" />
    </div>

    {#if error}
      <div class="alert alert-danger" role="alert" transition:fade>{error}</div>
    {/if}

    {#if success}
      <div class="alert alert-success" role="alert" transition:fade>{success}</div>
    {/if}

    {#if loading}
      <div class="text-center">
        <div class="spinner-large"></div>
        <p class="neon-text-cyan mt-2">Loading users…</p>
      </div>
    {:else if users.length === 0}
      <div class="text-center p-4">
        <p class="neon-text-cyan">No users found</p>
      </div>
    {:else}
      <div class="glass">
        <table class="table-dark">
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
              <tr on:click={() => openUserDetail(user)} style="cursor:pointer;" class="hover-glow">
                <td class="neon-text-white">{user.email}</td>
                <td>{user.display_name || '-'}</td>
                <td>{formatDate(user.created_at)}</td>
                <td>
                  <span class="badge {user.is_admin ? 'badge-warning' : 'badge-info'}">
                    {user.is_admin ? 'Admin' : 'User'}
                  </span>
                </td>
                <td>
                  <span class="badge {user.role === 'pos' ? 'badge-success' : 'badge-secondary'}">
                    {user.role === 'pos' ? 'Yes' : 'No'}
                  </span>
                </td>
                <td>
                  {#if typeof balance !== 'number'}
                    <span class="text-muted">Loading...</span>
                  {:else if balance < 0}
                    <span class="text-red-400">Debt: R{Math.abs(balance).toFixed(2)}</span>
                  {:else if balance > 0}
                    <span class="text-green-400">Credit: R{balance.toFixed(2)}</span>
                  {:else}
                    <span class="text-muted">R0.00</span>
                  {/if}
                  <button class="btn btn-secondary btn-sm ml-2" on:click|stopPropagation={() => openLedgerModal(user)} title="View Ledger">📄</button>
                </td>
                <td>
                  <button 
                    class="btn btn-danger btn-sm"
                    on:click|stopPropagation={() => confirmDeleteUser(user)}
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
    {/if}

    {#if ledgerModalUser}
      <div class="modal-backdrop" on:click={closeLedgerModal}>
        <div class="modal-content" on:click|stopPropagation>
          <div class="modal-header">
            <h2 class="neon-text-cyan">Ledger for {ledgerModalUser.email}</h2>
            <button class="modal-close" on:click={closeLedgerModal}>&times;</button>
          </div>
          <div class="modal-body">
            {#if loadingLedger}
              <div class="text-center">
                <div class="spinner"></div>
                <p class="neon-text-cyan mt-2">Loading ledger entries...</p>
              </div>
            {:else if ledgerError}
              <div class="alert alert-danger">{ledgerError}</div>
            {:else if ledgerEntries.length === 0}
              <div class="text-center text-muted">No ledger entries for this user.</div>
            {:else}
              <table class="table-dark">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Type</th>
                    <th>Amount</th>
                    <th>Order</th>
                  </tr>
                </thead>
                <tbody>
                  {#each ledgerEntries as entry}
                    <tr>
                      <td>{new Date(entry.created_at).toLocaleString()}</td>
                      <td><span class="badge badge-info">{entry.category}</span></td>
                      <td class="{entry.total_amount < 0 ? 'text-red-400' : entry.total_amount > 0 ? 'text-green-400' : 'neon-text-cyan'}">
                        {entry.total_amount < 0 ? `-R${Math.abs(entry.total_amount).toFixed(2)}` : `R${entry.total_amount.toFixed(2)}`}
                      </td>
                      <td class="neon-text-cyan">{entry.order_id || '-'}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            {/if}
          </div>
          <div class="modal-actions">
            <button class="btn btn-secondary" on:click={closeLedgerModal}>Close</button>
          </div>
        </div>
      </div>
    {/if}

    {#if showDeleteModal && userToDelete}
      <div class="modal-backdrop" role="dialog" aria-modal="true" tabindex="-1" on:keydown={(e) => { if (e.key === 'Escape') cancelDeleteUser(); }}>
        <div class="modal-content" role="document" tabindex="0" on:click|stopPropagation style="max-width: 500px;">
          <div class="modal-header">
            <h2 id="delete-modal-title" class="neon-text-cyan">Confirm Delete</h2>
            <button class="modal-close" on:click={cancelDeleteUser}>&times;</button>
          </div>
          <div class="modal-body">
            <p class="neon-text-white">Are you sure you want to delete user <strong class="neon-text-cyan">{userToDelete.email}</strong>?</p>
          </div>
          <div class="modal-actions">
            <button class="btn btn-secondary" on:click={cancelDeleteUser} aria-label="Cancel delete">Cancel</button>
            <button class="btn btn-danger" on:click={handleDeleteUser} aria-label="Confirm delete user">Delete</button>
          </div>
        </div>
      </div>
    {/if}

    {#if selectedUser}
      <div class="modal-backdrop" on:click={closeUserDetail}>
        <div class="modal-content user-detail-modal" on:click|stopPropagation>
          <div class="modal-header">
            <h2 class="neon-text-cyan">User Details: {selectedUser.display_name || selectedUser.email}</h2>
            <button class="modal-close" on:click={closeUserDetail}>×</button>
          </div>
          <div class="modal-body">
            <div class="grid grid-2 gap-3 mb-4">
              <div class="glass-light p-3">
                <strong class="neon-text-cyan">Email:</strong> 
                <span class="neon-text-white">{selectedUser.email}</span>
              </div>
              <div class="glass-light p-3">
                <strong class="neon-text-cyan">Joined:</strong> 
                <span class="neon-text-white">{formatDate(selectedUser.created_at)}</span>
              </div>
              <div class="glass-light p-3">
                <strong class="neon-text-cyan">Debt/Credit:</strong> 
                <span class="{userStats.debt < 0 ? 'text-red-400' : 'text-green-400'}">
                  {userStats.debt < 0 ? `Debt: R${Math.abs(userStats.debt).toFixed(2)}` : `Credit: R${userStats.debt.toFixed(2)}`}
                </span>
              </div>
              <div class="glass-light p-3">
                <strong class="neon-text-cyan">Total Orders:</strong> 
                <span class="neon-text-white">{userStats.totalOrders}</span>
              </div>
              <div class="glass-light p-3">
                <strong class="neon-text-cyan">Total Spent:</strong> 
                <span class="neon-text-white">R{userStats.totalSpent.toFixed(2)}</span>
              </div>
              {#if contractUrl}
                <div class="glass-light p-3">
                  <button on:click={downloadContract} class="btn btn-primary btn-sm">Download Signed Contract</button>
                </div>
              {/if}
            </div>

            <div class="glass p-3 mb-4">
              <h4 class="neon-text-cyan mb-3">Adjust Balance</h4>
              <div class="grid grid-2 gap-2 mb-3">
                <div class="form-group">
                  <label for="adjustment-amount" class="form-label">Amount (R)</label>
                  <input id="adjustment-amount" type="number" placeholder="e.g., 500" bind:value={adjustmentAmount} class="form-control" />
                </div>
                <div class="form-group">
                  <label for="adjustment-note" class="form-label">Note (Optional)</label>
                  <input id="adjustment-note" type="text" placeholder="Reason for adjustment" bind:value={adjustmentNote} class="form-control" />
                </div>
              </div>
              <div class="flex gap-2">
                <button class="btn btn-success" on:click={() => {if (selectedUser) handleBalanceAdjustment(selectedUser, false)}}>+ Add Credit</button>
                <button class="btn btn-danger" on:click={() => {if (selectedUser) handleBalanceAdjustment(selectedUser, true)}}>- Add Debt</button>
              </div>
            </div>
            
            <div class="glass mb-4">
              <div class="card-header">
                <h3 class="neon-text-cyan">Orders</h3>
              </div>
              <div class="card-body">
                {#if userOrdersLoading}
                  <div class="text-center">
                    <div class="spinner"></div>
                    <p class="neon-text-cyan mt-2">Loading orders...</p>
                  </div>
                {:else if userOrdersError}
                  <div class="alert alert-danger">{userOrdersError}</div>
                {:else if userOrders.length === 0}
                  <div class="text-center text-muted">No orders found for this user.</div>
                {:else}
                  <table class="table-dark">
                    <thead>
                      <tr>
                        <th>Date</th>
                        <th>Status</th>
                        <th>Total</th>
                        <th>Order #</th>
                        <th>Note</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each userOrders as order}
                        <tr>
                          <td>{formatDate(order.created_at)}</td>
                          <td><span class="badge badge-info">{order.status}</span></td>
                          <td class="neon-text-cyan">R{order.total.toFixed(2)}</td>
                          <td class="neon-text-white">{order.order_number}</td>
                          <td>{order.note || '-'}</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                {/if}
              </div>
            </div>

            <div class="glass">
              <div class="card-header">
                <h3 class="neon-text-cyan">Ledger Entries</h3>
              </div>
              <div class="card-body">
                {#if userLedgerLoading}
                  <div class="text-center">
                    <div class="spinner"></div>
                    <p class="neon-text-cyan mt-2">Loading ledger...</p>
                  </div>
                {:else if userLedgerError}
                  <div class="alert alert-danger">{userLedgerError}</div>
                {:else if userLedger.length === 0}
                  <div class="text-center text-muted">No ledger entries for this user.</div>
                {:else}
                  <table class="table-dark">
                    <thead>
                      <tr>
                        <th>Date</th>
                        <th>Type</th>
                        <th>Amount</th>
                        <th>Order</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each userLedger as entry}
                        <tr>
                          <td>{formatDate(entry.created_at)}</td>
                          <td><span class="badge badge-info">{entry.category}</span></td>
                          <td class="{entry.total_amount < 0 ? 'text-red-400' : entry.total_amount > 0 ? 'text-green-400' : 'neon-text-cyan'}">
                            {entry.total_amount < 0 ? `-R${Math.abs(entry.total_amount).toFixed(2)}` : `R${entry.total_amount.toFixed(2)}`}
                          </td>
                          <td class="neon-text-cyan">{entry.order_id || '-'}</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                {/if}
              </div>
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</main>

<style>
  .admin-main {
    min-height: 100vh;
    padding-top: 80px;
    background: transparent;
  }

  .admin-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
  }

  .admin-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 2rem;
    margin-bottom: 2rem;
  }

  .admin-header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    letter-spacing: 1px;
  }

  .user-detail-modal {
    max-width: 90vw;
    width: 800px;
    max-height: 90vh;
  }

  .text-red-400 {
    color: #f87171;
  }

  .text-green-400 {
    color: #4ade80;
  }

  .text-muted {
    color: var(--text-muted);
  }

  .ml-2 {
    margin-left: 0.5rem;
  }

  @media (max-width: 768px) {
    .admin-container {
      padding: 1rem;
    }
    
    .admin-header {
      flex-direction: column;
      gap: 1rem;
      align-items: stretch;
    }
    
    .admin-header h1 {
      font-size: 2rem;
    }
    
    .admin-header input {
      max-width: 100%;
      width: 100%;
    }
    
    .user-detail-modal {
      width: 95vw;
    }
  }
</style> 