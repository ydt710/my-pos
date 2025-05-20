<script lang="ts">
  import { tick } from 'svelte';
  import { cartStore, cartNotification, selectedPosUser } from '$lib/stores/cartStore';
  import { goto } from '$app/navigation';
  import CartItem from './CartItem.svelte';
  import { supabase } from '$lib/supabase';
  import { fade } from 'svelte/transition';
  import { getUserBalance } from '$lib/services/orderService';
  import { get } from 'svelte/store';
  
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
  
  const FLOAT_USER_ID = '27cfee48-5b04-4ee1-885f-b3ef31417099';
  const FLOAT_USER_EMAIL = 'float@pos.local';
  
  // Clear float user if selected (e.g. from localStorage)
  const currentSelected = get(selectedPosUser);
  if (currentSelected && (currentSelected.id === FLOAT_USER_ID || currentSelected.email === FLOAT_USER_EMAIL)) {
    selectedPosUser.set(null);
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
    selectedPosUser.set(user);
    // Fetch and display balance for selected user
    fetchUserBalance(user.id);
  }
  
  async function fetchUserBalance(userId: string) {
    selectedUserBalance = await getUserBalance(userId);
  }
  
  function goToCheckout() {
    if ($cartStore.length === 0) return;
    toggleVisibility();
    goto('/checkout');
  }
  
  // When the cart becomes visible, focus it for accessibility
  $: if (visible) {
    tick().then(() => cartSidebar?.focus());
  }
  
  // Handle Escape key to close cart
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      toggleVisibility();
    }
  }
  
  // Clear selected user when cart is closed
  $: if (!visible && isPosUser) {
    selectedUser = null;
    userSearch = '';
    userResults = [];
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
          email: newAccount.email.trim() || null,
          balance: 0 // Ensure balance is initialized
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
  }
</script>

<div 
  class="cart-container {visible ? 'show' : ''}" 
  bind:this={cartSidebar}
  tabindex="-1"
  role="dialog"
  aria-modal="true"
  aria-label="Shopping cart"
  on:keydown={handleKeydown}
>
  <div class="cart-header">
    <h2>Your Cart ({cartStore.getItemCount($cartStore)} items)</h2>
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
        on:input={searchUsers}
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
      {#if selectedUser}
        <div class="selected-user">
          Assigned to: <strong>{selectedUser.display_name || selectedUser.email}</strong>
          <br />
          <span>
            Balance: <span style="color: {(selectedUserBalance ?? 0) > 0 ? '#28a745' : (selectedUserBalance ?? 0) < 0 ? '#dc3545' : '#666'};">
              R{selectedUserBalance ?? 0}
            </span>
          </span>
        </div>
      {/if}
    </div>
    {#if showAddAccountModal}
      <div class="modal-backdrop" transition:fade></div>
      <div class="modal add-account-modal" transition:fade>
        <h3>Add New Account</h3>
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
            <button type="button" on:click={() => showAddAccountModal = false} class="cancel-btn">Cancel</button>
            <button type="submit" class="submit-btn" disabled={addAccountLoading}>
              {addAccountLoading ? 'Adding...' : 'Add Account'}
            </button>
          </div>
        </form>
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
        <CartItem {item} {loading} />
      {/each}
    </div>
    
    <div class="cart-footer">
      <h3>Total: R{cartStore.getTotal($cartStore)}</h3>
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
    width: 320px;
    height: 60vh;
    max-height: 60vh;
    background: rgba(255, 255, 255, 0.9);
    backdrop-filter: blur(10px);
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
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
    position: sticky;
    top: 0;
    background: rgba(255, 255, 255, 0.9);
    backdrop-filter: blur(10px);
    z-index: 2001;
  }

  .cart-header h2 {
    margin: 0;
    font-size: 1.25rem;
    color: #333;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
    color: #666;
    transition: all 0.2s;
  }

  .close-btn:hover {
    color: #333;
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
  }

  .checkout-btn {
    width: 100%;
    padding: 0.75rem;
    background: linear-gradient(135deg, #2196f3, #1976d2);
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
    color: #666;
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
    color: #666;
    padding: 1rem;
  }

  .pos-user-search {
    margin-bottom: 1rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }

  .pos-user-search label {
    font-weight: 500;
    display: block;
    margin-bottom: 0.25rem;
    color: #333;
  }

  .pos-user-search input {
    width: 100%;
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

  .modal.add-account-modal h3 {
    margin-top: 0;
    margin-bottom: 1rem;
    font-size: 1.3rem;
    color: #333;
    text-align: center;
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
    padding: 0.75rem;
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

  @media (max-width: 768px) {
    .cart-container {
      max-height: 100vh;
      top: 0;
      right: 0;
      margin-top: 0;
      border-radius: 0;
      z-index: 100;
    }
  }
</style> 