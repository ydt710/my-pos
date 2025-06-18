<script lang="ts">
  import { tick, onMount } from 'svelte';
  import { cartStore, cartNotification, selectedPosUser, fetchCustomPricesForUser, customPrices, getItemCount, getTotal } from '$lib/stores/cartStore';
  import { goto } from '$app/navigation';
  import CartItem from './CartItem.svelte';
  import { supabase } from '$lib/supabase';
  import { fade } from 'svelte/transition';
  import { getUserBalance } from '$lib/services/orderService';
  import { get } from 'svelte/store';
  import { debounce, getBalanceColor } from '$lib/utils';
  import { FLOAT_USER_ID, FLOAT_USER_EMAIL } from '$lib/constants';
  
  export let visible = false;
  export let toggleVisibility: () => void;
  export let isPosUser = false;
  
  let loading = false;
  let cartSidebar: HTMLDivElement;
  
  // POS user search state
  let userSearch = '';
  type UserSearch = { id: string; display_name: string | null; email: string };
  let userResults: UserSearch[] = [];
  let selectedUser: UserSearch | null = null;
  let userLoading = false;
  let showAddAccountModal = false;
  let newAccount = { display_name: '', phone_number: '', email: '' };
  let addAccountError = '';
  let addAccountLoading = false;
  let selectedUserBalance: number | null = null;
  let searchDebounce: NodeJS.Timeout | null = null;
  let lastFocusedElement: HTMLElement | null = null;
  
  // ARIA live region for dynamic feedback
  let liveMessage = '';
  $: if (userLoading) liveMessage = 'Searching users...';
  $: if (addAccountError) liveMessage = addAccountError;
  $: if ($cartNotification) liveMessage = $cartNotification.message;
  
  // Debounced user search
  const debouncedSearchUsers = debounce(() => searchUsers(), 300);
  
  function handleUserSearchInput() {
    debouncedSearchUsers();
  }
  
  async function searchUsers() {
    if (userSearch.length < 2) {
      userResults = [];
      return;
    }
    userLoading = true;
    const { data, error } = await supabase
      .from('profiles')
      .select('id, display_name, email')
      .or(`display_name.ilike.%${userSearch}%,email.ilike.%${userSearch}%`)
      .limit(10);
    userResults = (data || []).filter(user => user.id !== FLOAT_USER_ID && user.email !== FLOAT_USER_EMAIL);
    userLoading = false;
  }
  
  function selectUser(user: UserSearch) {
    selectedUser = user;
    userResults = [];
    userSearch = user.display_name || user.email;
    // Map UserSearch to User for PosUser
    selectedPosUser.set({
      id: user.id,
      email: user.email,
      name: user.display_name || undefined,
      balance: selectedUserBalance ?? 0
    });
    // Fetch and display balance for selected user
    fetchUserBalance(user.id);
    // Fetch custom prices for this user
    fetchCustomPricesForUser(user.id);
  }
  
  async function fetchUserBalance(userId: string) {
    selectedUserBalance = await getUserBalance(userId);
  }
  
  function goToCheckout() {
    if ($cartStore.length === 0) return;
    toggleVisibility();
    goto('/checkout');
  }
  
  // Focus management for sidebar and modal
  $: if (visible) {
    tick().then(() => {
      lastFocusedElement = document.activeElement as HTMLElement;
      cartSidebar?.focus();
    });
  }
  function restoreFocus() {
    lastFocusedElement?.focus();
  }
  
  // Keyboard handling for sidebar and modal
  function handleSidebarKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      toggleVisibility();
      restoreFocus();
    }
    // Trap focus in sidebar (implement if needed)
  }
  function handleModalKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      showAddAccountModal = false;
      tick().then(() => {
        document.getElementById('user-search')?.focus();
      });
    }
    // Trap focus in modal (implement if needed)
  }
  
  // Clear selected user when cart is closed
  $: if (!visible && isPosUser) {
    selectedUser = null;
    userSearch = '';
    userResults = [];
    customPrices.set({}); // Clear custom prices when cart is closed
    restoreFocus();
  }
  
  async function addAccount() {
    addAccountError = '';
    if (!newAccount.display_name.trim()) {
      addAccountError = 'Display name is required.';
      return;
    }
    addAccountLoading = true;
    // Insert into profiles (email can be empty)
    const { data, error } = await supabase
      .from('profiles')
      .insert([
        {
          display_name: newAccount.display_name.trim(),
          phone_number: newAccount.phone_number.trim(),
          email: newAccount.email.trim() || null
        }
      ])
      .select()
      .single();
    addAccountLoading = false;
    if (error) {
      addAccountError = error.message || 'Failed to add account.';
      return;
    }
    // Auto-select the new user
    selectUser(data);
    showAddAccountModal = false;
    newAccount = { display_name: '', phone_number: '', email: '' };
    tick().then(() => {
      document.getElementById('user-search')?.focus();
    });
  }
  
  $: posUser = $selectedPosUser;

  $: if (posUser && posUser.id) {
    fetchCustomPricesForUser(posUser.id);
  } else {
    customPrices.set({});
  }
</script>

<!-- ARIA live region for dynamic feedback -->
<div aria-live="polite" class="sr-only" style="position:absolute;left:-9999px;">{liveMessage}</div>

<div 
  class="cart-container {visible ? 'show' : ''}" 
  bind:this={cartSidebar}
  tabindex="-1"
  role="dialog"
  aria-modal="true"
  aria-label="Shopping cart"
  on:keydown={handleSidebarKeydown}
>
  <div class="cart-header">
    <h2>Your Cart ({getItemCount($cartStore)} items)</h2>
    <button 
      class="close-btn" 
      aria-label="Close cart" 
      on:click={toggleVisibility}
    >×</button>
  </div>
  
  {#if isPosUser}
    <div class="pos-user-search">
      <label for="user-search">Assign to Customer</label>
      <input
        id="user-search"
        type="text"
        placeholder="Search name or email..."
        bind:value={userSearch}
        on:input={handleUserSearchInput}
        autocomplete="off"
      />
      <button class="add-account-btn" type="button" on:click={() => showAddAccountModal = true}>+ Add Account</button>
      {#if userLoading}
        <div class="user-loading">Searching...</div>
      {/if}
      {#if userResults.length > 0}
        <ul class="user-results">
          {#each userResults as user}
            <li>
              <button type="button" class="user-select-btn" on:click={() => selectUser(user)}>
                {user.display_name || user.email} <span class="user-email">({user.email})</span>
              </button>
            </li>
          {/each}
        </ul>
      {/if}
      {#if posUser}
        <div class="selected-user">
          Assigned to: <strong>{posUser.name || posUser.email}</strong>
          <br />
          <span>
            Balance: <span style="color: {(selectedUserBalance ?? 0) > 0 ? '#28a745' : (selectedUserBalance ?? 0) < 0 ? '#dc3545' : '#666'};">
              R{selectedUserBalance ?? 0}
            </span>
          </span>
          <button class="clear-user-btn" on:click={() => { selectedPosUser.set(null); selectedUser = null; }} style="margin-top:0.5rem;">Guest Checkout</button>
        </div>
      {:else}
        <div class="selected-customer-info warning">
          <strong>No customer selected.</strong> Guest checkout mode.
        </div>
      {/if}
    </div>
    {#if showAddAccountModal}
      <div class="modal-backdrop" transition:fade></div>
      <div class="modal add-account-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title" transition:fade>
        <div class="modal-header">
          <h2 id="modal-title" tabindex="-1">Add New Account</h2>
          <button type="button" on:click={() => showAddAccountModal = false} class="cancel-btn" aria-label="Close">×</button>
        </div>
        <div class="modal-content" role="document">
          <form on:submit|preventDefault={addAccount}>
            <div class="form-group">
              <label for="new-display-name">Display Name*</label>
              <input id="new-display-name" type="text" bind:value={newAccount.display_name} required />
            </div>
            <div class="form-group">
              <label for="new-phone-number">Phone Number (optional)</label>
              <input id="new-phone-number" type="text" bind:value={newAccount.phone_number} />
            </div>
            <div class="form-group">
              <label for="new-email">Email (optional)</label>
              <input id="new-email" type="email" bind:value={newAccount.email} />
            </div>
            {#if addAccountError}
              <div class="error-message">{addAccountError}</div>
            {/if}
            <div class="modal-actions">
              <button type="submit" class="submit-btn" disabled={addAccountLoading}>
                {addAccountLoading ? 'Adding...' : 'Add Account'}
              </button>
            </div>
          </form>
        </div>
      </div>
    {/if}
  {/if}
  
  {#if $cartNotification}
    <div 
      class="notification {$cartNotification.type}" 
      role="alert"
    >
      {$cartNotification.message}
    </div>
  {/if}
  
  {#if loading}
    <div class="loading">Updating cart...</div>
  {/if}
  
  {#if $cartStore.length > 0}
    <div class="cart-items">
      {#each $cartStore as item (item.id)}
        <CartItem {item} {loading} userId={posUser ? posUser.id : null} />
      {/each}
    </div>
    
    <div class="cart-footer">
      <h3>Total: R{getTotal($cartStore)}</h3>
      <button 
        on:click={goToCheckout} 
        class="checkout-btn" 
        disabled={$cartStore.length === 0 || loading}
      >
        Proceed to Checkout
      </button>
    </div>
  {:else}
    <p class="empty-cart">Your cart is empty.</p>
  {/if}
</div>

<style>
  .cart-container {
    position: fixed;
    top: 0;
    right: 0;
    height: 60vh;
    max-height: 60vh;
    backdrop-filter: blur(50px);
    box-shadow: -5px 0 15px rgba(0, 0, 0, 0.1);
    padding: 1rem;
    transform: translateX(100%);
    transition: transform 0.2s ease-out;
    overflow-y: auto;
    z-index: 2000;
    display: flex;
    flex-direction: column;
    margin-top: 20vh;
    border-radius: 12px 0 0 12px;
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 5%;
    width:60%;
  }

  .cart-container.show {
    transform: translateX(0);
  }

  .cart-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.75rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid wheat;
    position: sticky;
    top: 0;
    
    backdrop-filter: blur(10px);
    z-index: 2001;
  }

  .cart-header h2 {
    margin: 0;
    font-size: 1.25rem;
    color: wheat;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
    color: wheat;
    transition: all 0.2s;
  }

  .close-btn:hover {
    color: #00ff62;
    transform: scale(1.1);
  }

  .cart-items {
    flex-grow: 1;
    overflow-y: auto;
    z-index: 2000;
  }

  .cart-footer {
    margin-top: auto;
    padding-top: 1rem;
    border-top: 1px solid rgba(0, 0, 0, 0.1);
    color: wheat;
  }

  .checkout-btn {
    width: 100%;
    padding: 0.75rem;
    background: linear-gradient(161deg, #db92c6, #1b8260);
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s;
  }

  .checkout-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
  }

  .checkout-btn:disabled {
    background: #e0e0e0;
    cursor: not-allowed;
  }

  .empty-cart {
    text-align: center;
    color: wheat;
    margin: 2rem 0;
  }

  .notification {
    padding: 0.75rem;
    margin-bottom: 1rem;
    border-radius: 8px;
    backdrop-filter: blur(4px);
  }

  .notification.success {
    background: rgba(212, 237, 218, 0.9);
    color: #155724;
  }

  .notification.error {
    background: rgba(248, 215, 218, 0.9);
    color: #721c24;
  }

  .loading {
    text-align: center;
    color: rgb(247, 247, 247)fff;
    padding: 1rem;
  }

  .pos-user-search {
    margin-bottom: 1rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid rgb(255, 255, 255);
  }

  .pos-user-search label {
    font-weight: 500;
    display: block;
    margin-bottom: 0.25rem;
    color: #16ff1a;
  }

  .pos-user-search input {
    
    padding: 0.75rem;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    margin-bottom: 0.25rem;
    background: rgba(255, 255, 255, 0.9);
    transition: all 0.2s;
  }

  .pos-user-search input:focus {
    outline: none;
    border-color: #2196f3;
    box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
  }

  .user-results {
    list-style: none;
    margin: 0;
    padding: 0;
    background: rgba(255, 255, 255, 0.95);
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    max-height: 180px;
    overflow-y: auto;
    position: absolute;
    width: 90%;
    z-index: 10;
    backdrop-filter: blur(10px);
  }

  .user-results li {
    padding: 0.5rem;
    cursor: pointer;
    transition: background 0.15s;
  }

  .user-results li:hover {
    background: rgba(0, 0, 0, 0.05);
  }

  .user-email {
    color: #888;
    font-size: 0.9em;
  }

  .selected-user {
    margin-top: 0.5rem;
    font-size: 0.95em;
    color: #2196f3;
    padding: 0.75rem;
    background: rgba(33, 150, 243, 0.1);
    border-radius: 8px;
  }

  .user-loading {
    font-size: 0.95em;
    color: #666;
    margin-bottom: 0.25rem;
  }

  .add-account-btn {
    margin-top: 0.5rem;
    padding: 0.75rem 1rem;
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1rem;
    margin-bottom: 0.5rem;
    transition: all 0.2s;
  }

  .add-account-btn:hover {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
  }

  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(4px);
    z-index: 1001;
  }

  .modal.add-account-modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    padding: 2rem 1.5rem;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    z-index: 1002;
    min-width: 320px;
    max-width: 95vw;
    border: 1px solid rgba(255, 255, 255, 0.2);
  }

  .modal.add-account-modal .form-group {
    margin-bottom: 1rem;
  }

  .modal.add-account-modal label {
    display: block;
    margin-bottom: 0.25rem;
    color: #555;
    font-weight: 500;
  }

  .modal.add-account-modal input {
    width: 100%;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    font-size: 1rem;
    background: rgba(255, 255, 255, 0.9);
    transition: all 0.2s;
  }

  .modal.add-account-modal input:focus {
    outline: none;
    border-color: #2196f3;
    box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    margin-top: 1rem;
  }

  .cancel-btn {
    background: #e0e0e0;
    color: #333;
    border: none;
    border-radius: 8px;
    padding: 0.75rem 1rem;
    cursor: pointer;
    font-size: 1rem;
    transition: all 0.2s;
  }

  .cancel-btn:hover {
    background: #d0d0d0;
    transform: translateY(-1px);
  }

  .submit-btn {
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    border: none;
    border-radius: 8px;
    padding: 0.75rem 1rem;
    cursor: pointer;
    font-size: 1rem;
    transition: all 0.2s;
  }

  .submit-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
  }

  .submit-btn:disabled {
    background: #e0e0e0;
    cursor: not-allowed;
  }

  .error-message {
    color: #dc3545;
    margin-bottom: 0.5rem;
    text-align: center;
    padding: 0.75rem;
    background: rgba(220, 53, 69, 0.1);
    border-radius: 8px;
  }

  .user-select-btn {
    width: 100%;
    background: none;
    border: none;
    text-align: left;
    padding: 0.75rem;
    cursor: pointer;
    font-size: 1rem;
    color: #333;
    transition: all 0.2s;
  }

  .user-select-btn:hover, .user-select-btn:focus {
    background: rgba(0, 0, 0, 0.05);
    outline: none;
  }

  @media (max-width: 800px) {
    .cart-container {
      height: 100vh;
      max-height: 90vh;
      margin-top: 0;
      top: 0;
      right: 0;
      z-index: 2001;
    }
  }

  .modal-header {
    position: sticky;
    top: 0;
    background: white;
    z-index: 10;
    padding: 1rem;
    border-bottom: 1px solid #ccc;
  }
</style> 