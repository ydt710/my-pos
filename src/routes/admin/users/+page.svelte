<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { fade } from 'svelte/transition';
  import { getUserAvailableCredit } from '$lib/services/orderService';
  import { onDestroy } from 'svelte';
  import type { Transaction } from '$lib/types/ledger';
  import { debounce } from '$lib/utils';

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
    const promises = users.map(user => getUserAvailableCredit(user.id));
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
        userStats.debt = userLedger.reduce((sum, e) => sum + (e.amount || 0), 0);
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
    
    const { error: rpcError } = await supabase.rpc('admin_adjust_user_balance', {
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

<div class="users-page" in:fade>
  <header class="page-header">
    <h1>User Management</h1>
    <input placeholder="Search users…" value={searchTerm} on:input={onSearch} />
  </header>

  {#if error}
    <div class="alert error" role="alert" transition:fade>{error}</div>
  {/if}

  {#if success}
    <div class="alert success" role="alert" transition:fade>{success}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading users…</div>
  {:else if users.length === 0}
    <div class="no-users">No users found</div>
  {:else}
    <div class="table-card">
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
              <tr on:click={() => openUserDetail(user)} style="cursor:pointer;">
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
                    <span style="color: #666;">R0.00</span>
                  {/if}
                  <button class="ledger-btn" on:click|stopPropagation={() => openLedgerModal(user)} title="View Ledger">📄</button>
                </td>
                <td>
                  <button 
                    class="delete-user-btn"
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
    </div>
  {/if}

  {#if ledgerModalUser}
    <div class="modal-backdrop" on:click={closeLedgerModal}>
      <div class="modal-content" on:click|stopPropagation>
        <div class="modal-header">
          <h2>Ledger for {ledgerModalUser.email}</h2>
          <button class="close-btn" on:click={closeLedgerModal}>&times;</button>
        </div>
        <div class="modal-body">
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
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
        <div class="modal-actions">
          <button class="cancel-btn" on:click={closeLedgerModal}>Close</button>
        </div>
      </div>
    </div>
  {/if}

  {#if showDeleteModal && userToDelete}
    <div class="modal-backdrop" role="dialog" aria-modal="true" tabindex="-1" on:keydown={(e) => { if (e.key === 'Escape') cancelDeleteUser(); }}>
      <div class="modal-content" role="document" tabindex="0" on:click|stopPropagation style="max-width: 500px;">
        <div class="modal-header">
          <h2 id="delete-modal-title">Confirm Delete</h2>
        </div>
        <div class="modal-body">
          <p>Are you sure you want to delete user <strong>{userToDelete.email}</strong>?</p>
        </div>
        <div class="modal-actions">
          <button class="cancel-btn" on:click={cancelDeleteUser} aria-label="Cancel delete">Cancel</button>
          <button class="delete-user-btn" on:click={handleDeleteUser} aria-label="Confirm delete user">Delete</button>
        </div>
      </div>
    </div>
  {/if}

  {#if selectedUser}
    <div class="modal-backdrop" on:click={closeUserDetail}>
      <div class="modal-content" on:click|stopPropagation>
        <div class="modal-header">
          <h2>User Details: {selectedUser.display_name || selectedUser.email}</h2>
          <button class="close-btn" on:click={closeUserDetail}>×</button>
        </div>
        <div class="modal-body">
          <div class="user-details-grid">
            <div class="detail-item"><strong>Email:</strong> {selectedUser.email}</div>
            <div class="detail-item"><strong>Joined:</strong> {formatDate(selectedUser.created_at)}</div>
            <div class="detail-item"><strong>Debt/Credit:</strong> {userStats.debt < 0 ? `Debt: R${Math.abs(userStats.debt).toFixed(2)}` : `Credit: R${userStats.debt.toFixed(2)}`}</div>
            <div class="detail-item"><strong>Total Orders:</strong> {userStats.totalOrders}</div>
            <div class="detail-item"><strong>Total Spent:</strong> R{userStats.totalSpent.toFixed(2)}</div>
            {#if contractUrl}
              <div class="detail-item"><button on:click={downloadContract}>Download Signed Contract</button></div>
            {/if}
          </div>

          <div class="balance-adjustment-section">
            <h4>Adjust Balance</h4>
            <div class="form-group">
              <label for="adjustment-amount">Amount (R)</label>
              <input id="adjustment-amount" type="number" placeholder="e.g., 500" bind:value={adjustmentAmount} />
            </div>
            <div class="form-group">
              <label for="adjustment-note">Note (Optional)</label>
              <input id="adjustment-note" type="text" placeholder="Reason for adjustment" bind:value={adjustmentNote} />
            </div>
            <div class="adjustment-actions">
              <button class="btn-success" on:click={() => {if (selectedUser) handleBalanceAdjustment(selectedUser, false)}}>+ Add Credit</button>
              <button class="btn-danger" on:click={() => {if (selectedUser) handleBalanceAdjustment(selectedUser, true)}}>- Add Debt</button>
            </div>
          </div>
          
          <h3 style="margin-top:2rem;">Orders</h3>
          {#if userOrdersLoading}
            <div>Loading orders...</div>
          {:else if userOrdersError}
            <div class="error-message">{userOrdersError}</div>
          {:else if userOrders.length === 0}
            <div>No orders found for this user.</div>
          {:else}
            <table class="ledger-table">
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
                    <td>{order.status}</td>
                    <td>R{order.total.toFixed(2)}</td>
                    <td>{order.order_number}</td>
                    <td>{order.note || '-'}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {/if}
          <h3 style="margin-top:2rem;">Ledger Entries</h3>
          {#if userLedgerLoading}
            <div>Loading ledger...</div>
          {:else if userLedgerError}
            <div class="error-message">{userLedgerError}</div>
          {:else if userLedger.length === 0}
            <div>No ledger entries for this user.</div>
          {:else}
            <table class="ledger-table">
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
                    <td>{entry.type}</td>
                    <td style="color: {entry.amount < 0 ? '#dc3545' : entry.amount > 0 ? '#28a745' : '#333'};">
                      {entry.amount < 0 ? `-R${Math.abs(entry.amount).toFixed(2)}` : `R${entry.amount.toFixed(2)}`}
                    </td>
                    <td>{entry.order_id || '-'}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  :root {
    --primary: #007bff;
    --primary-dark: #0069d9;
    --danger: #dc3545;
    --danger-dark: #c82333;
    --success: #28a745;
    --success-dark: #218838;
    --muted: #6c757d;
    --light: #f8f9fa;
    --gray-border: #dee2e6;
    --font-main: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }
  body {
    font-family: var(--font-main);
    color: #333;
    background: #f4f5f7;
  }
  .btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.875rem;
    transition: all 0.2s;
    font-family: inherit;
  }
  .btn-primary {
    background: var(--primary);
    color: white;
  }
  .btn-primary:hover {
    background: var(--primary-dark);
  }
  .btn-danger {
    background: var(--danger);
    color: white;
  }
  .btn-danger:hover {
    background: var(--danger-dark);
  }
  .btn-success {
    background: var(--success);
    color: white;
  }
  .btn-success:hover {
    background: var(--success-dark);
  }
  .btn-secondary {
    background: var(--light);
    color: var(--muted);
  }
  .btn-secondary:hover {
    background: #e2e6ea;
  }
  .role-badge {
    padding: 0.2em 0.5em;
    border-radius: 4px;
    font-weight: bold;
  }
  .role-badge.admin {
    background: #ffc107;
    color: #333;
  }
  .text-muted {
    color: #888;
  }
  .text-debt {
    color: var(--danger);
  }
  .text-credit {
    color: var(--success);
  }
  .table-card {
    background: white;
    padding: 1.5rem;
    border-radius: 12px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 1.5rem;
  }
  .table-responsive {
    overflow-x: auto;
  }
  .users-table {
    width: 100%;
    border-collapse: collapse;
  }
  .users-table th, .users-table td {
    padding: 0.75em 1em;
    border-bottom: 1px solid #ddd;
  }
  .users-table-container {
    margin-top: 2rem;
  }
  @media (max-width: 1000px) {
    .users-table {
      font-size: 0.95rem;
    }
  }
  @media (max-width: 800px) {
    .users-table {
      min-width: 800px;
    }
    .users-table th,
    .users-table td {
      padding: 0.5rem;
    }
  }
  @media (max-width: 600px) {
    .page-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 1rem;
    }
    .page-header input {
      max-width: 100%;
      width: 100%;
    }
  }
  @media (max-width: 500px) {
    .modal-content {
      padding: 1rem;
    }
  }
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1000;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  .modal-content {
    background: white;
    padding: 0;
    border-radius: 12px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.3);
    max-width: 90vw;
    width: 800px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
  }
  button, input {
    transition: background 0.2s, color 0.2s, border-color 0.2s;
  }
  .alert {
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
  }
  .alert.error {
    background: #f8d7da;
    color: #721c24;
  }
  .alert.success {
    background: #d4edda;
    color: #155724;
  }
  .loading {
    text-align: center;
    padding: 2rem;
    color: #666;
  }
  .no-users {
    text-align: center;
    color: #888;
    padding: 2rem;
  }
  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 2rem;
    margin-bottom: 2rem;
  }
  .page-header input {
    max-width: 300px;
    width: 100%;
    padding: 0.5rem 1rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
    background: #fff;
    color: #222;
    box-shadow: 0 2px 8px rgba(0,0,0,0.03);
    transition: border-color 0.2s;
  }
  .page-header input:focus {
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 2px rgba(0,123,255,0.10);
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
    justify-content: flex-end;
    padding: 1rem 1.5rem;
    border-top: 1px solid var(--gray-border);
    background: #f8f9fa;
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
  .users-page{
    padding: 20px;
  }
  .modal-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 1rem 1.5rem;
      border-bottom: 1px solid var(--gray-border);
  }

  .modal-header h2 {
      margin: 0;
      font-size: 1.25rem;
  }

  .modal-body {
      padding: 1.5rem;
      overflow-y: auto;
  }

  .close-btn {
      background: none;
      border: none;
      font-size: 2rem;
      line-height: 1;
      cursor: pointer;
      padding: 0;
      color: var(--muted);
  }
  .user-details-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }
  .balance-adjustment-section {
    background: #f8f9fa;
    padding: 1.5rem;
    border-radius: 8px;
    margin-top: 1.5rem;
    border: 1px solid #e9ecef;
  }
  .balance-adjustment-section h4 {
    margin: 0 0 1rem;
    font-size: 1.1rem;
  }
  .form-group {
    margin-bottom: 1rem;
  }
  .form-group label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
  }
  .form-group input {
    width: 100%;
    padding: 0.5rem;
    border-radius: 4px;
    border: 1px solid #ccc;
  }
  .adjustment-actions {
    display: flex;
    gap: 1rem;
    margin-top: 1rem;
  }
  .adjustment-actions button {
    flex-grow: 1;
    padding: 0.75rem;
    border: none;
    border-radius: 6px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
  }
</style> 