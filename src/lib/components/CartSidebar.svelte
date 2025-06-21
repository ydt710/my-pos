<script lang="ts">
  import { tick, onMount, onDestroy } from 'svelte';
  import { cartStore, cartNotification, selectedPosUser, fetchCustomPricesForUser, customPrices, getItemCount, getTotal } from '$lib/stores/cartStore';
  import { goto } from '$app/navigation';
  import CartItem from './CartItem.svelte';
  import { supabase } from '$lib/supabase';
  import { fade } from 'svelte/transition';
  import { getUserBalance, getUserAvailableCredit } from '$lib/services/orderService';
  import { get } from 'svelte/store';
  import { debounce, getBalanceColor } from '$lib/utils';

  
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
  let selectedUserBalance: number | null = null;
  let selectedUserAvailableCredit: number | null = null;
  let lastFocusedElement: HTMLElement | null = null;
  
  // --- SEARCH OPTIMIZATION ---
  let searchTimeout: ReturnType<typeof setTimeout> | null = null;
  let searchCache: Record<string, UserSearch[]> = {};
  let searchAbortController: AbortController | null = null;
  // --- END SEARCH OPTIMIZATION ---
  
  // ARIA live region for dynamic feedback
  let liveMessage = '';
  $: if (userLoading) liveMessage = 'Searching users...';
  $: if ($cartNotification) liveMessage = $cartNotification.message;
  
  // Debounced user search (custom, not imported)
  function handleUserSearchInput() {
    if (searchTimeout) clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      searchUsers();
    }, 350);
  }
  
  async function searchUsers() {
    const query = userSearch.trim();
    if (query.length < 2) {
      userResults = [];
      return;
    }

    // Check cache first
    if (searchCache[query]) {
      userResults = searchCache[query];
      return;
    }

    // Cancel previous fetch if still running
    if (searchAbortController) {
      searchAbortController.abort();
    }
    searchAbortController = new AbortController();

    userLoading = true;
    try {
      const { data, error } = await supabase
        .rpc('search_all_users', { search_term: query })
        .abortSignal(searchAbortController.signal);

      if (error) throw error;
      
      // Filter out float user, etc.
      
      searchCache[query] = filtered; // Cache the result
    } catch (e: any) {
      if (e.name !== 'AbortError') {
        console.error(e);
      }
    } finally {
    userLoading = false;
    }
  }
  
  function selectUser(user: UserSearch) {
    selectedUser = user;
    userResults = [];
    userSearch = user.display_name || user.email;
    // Fetch and display balance for selected user
    getUserBalance(user.id).then(balance => {
      selectedUserBalance = balance;
      getUserAvailableCredit(user.id).then(credit => {
        selectedUserAvailableCredit = credit;
      });
      console.log('[CartSidebar] selectedUserBalance for', user.id, '=', balance);
      selectedPosUser.set({
        id: user.id,
        email: user.email,
        name: user.display_name || undefined,
      });
      fetchCustomPricesForUser(user.id);
    });
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
      toggleVisibility();
      restoreFocus();
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
  
  let posUserUnsubscribe: (() => void) | null = null;

  onMount(() => {
    posUserUnsubscribe = selectedPosUser.subscribe((val) => {
      (async () => {
        if (val && val.id) {
          selectedUserBalance = await getUserBalance(val.id);
          selectedUserAvailableCredit = await getUserAvailableCredit(val.id);
          // Optionally update selectedUser for UI
          selectedUser = { id: val.id, display_name: val.name ?? null, email: val.email };
        } else {
          selectedUserBalance = null;
          selectedUserAvailableCredit = null;
          selectedUser = null;
        }
      })();
    });
  });
  onDestroy(() => {
    if (posUserUnsubscribe) posUserUnsubscribe();
  });

  $: posUser = $selectedPosUser;

  $: if (posUser && posUser.id) {
    console.log('[CartSidebar] posUser changed:', posUser);
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
            {#if selectedUserAvailableCredit === null}
              Balance: <span style="color: #666;">Loading...</span>
            {:else if selectedUserAvailableCredit < 0}
              Debt: <span style="color: #dc3545;">R{Math.abs(selectedUserAvailableCredit).toFixed(2)}</span>
            {:else if selectedUserAvailableCredit > 0}
              Credit: <span style="color: #28a745;">R{selectedUserAvailableCredit.toFixed(2)}</span>
            {:else}
              Balance: <span style="color: #666;">R0.00</span>
            {/if}
          </span>
          <button class="clear-user-btn" on:click={() => { selectedPosUser.set(null); selectedUser = null; }} style="margin-top:0.5rem;">Guest Checkout</button>
        </div>
      {:else}
        <div class="selected-customer-info warning">
          <strong>No customer selected.</strong> Guest checkout mode.
        </div>
      {/if}
    </div>
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
    position: relative;
    z-index: 2002;
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
    width: 100%;
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
    z-index: 2002;
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