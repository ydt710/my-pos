<script lang="ts">
  import { tick, onMount, onDestroy } from 'svelte';
  import { pricedCart, cartNotification, selectedPosUser, fetchCustomPricesForUser, customPrices, cartItemCount, cartTotal } from '$lib/stores/cartStore';
  import { goto } from '$app/navigation';
  import CartItem from './CartItem.svelte';
  import { supabase } from '$lib/supabase';
  import { fade } from 'svelte/transition';
  import { getUserBalance } from '$lib/services/orderService';
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
      
      userResults = data || [];
      searchCache[query] = data || [];
      
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
      console.log('[CartSidebar] selectedUserBalance for', user.id, '=', balance);
      selectedPosUser.set({
        id: user.id,
        email: user.email,
        name: user.display_name || undefined,
      });
      fetchCustomPricesForUser(user.id);
    }).catch(error => {
      console.error('[CartSidebar] Error fetching balance for user', user.id, ':', error);
      selectedUserBalance = 0;
    });
  }
  
  function goToCheckout() {
    if ($pricedCart.length === 0) return;
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
    // customPrices.set({}); // Do NOT clear custom prices here!
    restoreFocus();
  }
  
  let posUserUnsubscribe: (() => void) | null = null;

  onMount(() => {
    posUserUnsubscribe = selectedPosUser.subscribe((val) => {
      (async () => {
        if (val && val.id) {
          fetchCustomPricesForUser(val.id);
          try {
            selectedUserBalance = await getUserBalance(val.id);
            console.log('[CartSidebar] Updated selectedUserBalance for', val.id, '=', selectedUserBalance);
          } catch (error) {
            console.error('[CartSidebar] Error updating balance for user', val.id, ':', error);
            selectedUserBalance = 0;
          }
          // Optionally update selectedUser for UI
          selectedUser = { id: val.id, display_name: val.name ?? null, email: val.email };
        } else {
          selectedUserBalance = null;
          selectedUser = null;
          customPrices.set({}); // Clear prices if user is cleared
        }
      })();
    });
  });
  onDestroy(() => {
    if (posUserUnsubscribe) posUserUnsubscribe();
  });

  $: posUser = $selectedPosUser;
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
    <h2>Your Cart ({$cartItemCount} items)</h2>
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
            {#if selectedUserBalance === null}
              Balance: <span style="color: #666;">Loading...</span>
            {:else if selectedUserBalance < 0}
              Debt: <span style="color: #dc3545;">R{Math.abs(selectedUserBalance).toFixed(2)}</span>
            {:else if selectedUserBalance > 0}
              Credit: <span style="color: #28a745;">R{selectedUserBalance.toFixed(2)}</span>
            {:else}
              Balance: <span style="color: #666;">R0.00</span>
            {/if}
          </span>
          {#if Object.keys($customPrices).length > 0}
            <div class="custom-prices-active">
              <span style="color: #007bff; font-size: 0.9em;">
                🏷️ Custom prices active ({Object.keys($customPrices).length} products)
              </span>
            </div>
          {/if}
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
  
  <div class="cart-items">
    {#if $pricedCart.length > 0}
      {#each $pricedCart as item (item.id)}
        <div in:fade>
          <CartItem {item} {loading} userId={posUser ? posUser.id : null} />
        </div>
      {/each}
    {:else}
      <div class="empty-cart" in:fade>
        <p>Your cart is empty.</p>
        <button on:click={toggleVisibility}>Start Shopping</button>
      </div>
    {/if}
  </div>
  
  <div class="cart-footer">
    <h3>Total: R{$cartTotal.toFixed(2)}</h3>
    <button 
      on:click={goToCheckout} 
      class="checkout-btn" 
      disabled={$pricedCart.length === 0 || loading}
    >
      Proceed to Checkout
    </button>
  </div>
</div>

<style>
  .cart-container {
    position: fixed;
    top: 0;
    right: 0;
    width: 420px;
    max-width: 100vw;
    height: 100vh;
    background: rgba(24, 28, 40, 0.82);
    backdrop-filter: blur(24px) saturate(1.2);
    box-shadow: -8px 0 32px 0 rgba(0,255,255,0.08), 0 0 0 2px rgba(0,242,254,0.12);
    border-left: 4px solid #00f2fe;
    border-radius: 0 18px 18px 0;
    z-index: 2000;
    display: flex;
    flex-direction: column;
    transform: translateX(100%);
    transition: transform 0.35s cubic-bezier(.77,0,.18,1);
    overflow: hidden;
  }

  .cart-container.show {
    transform: translateX(0);
  }

  .cart-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.2rem 1.5rem 1rem 1.5rem;
    border-bottom: 1.5px solid rgba(0,242,254,0.18);
    background: rgba(24,28,40,0.92);
    position: sticky;
    top: 0;
    z-index: 2;
  }

  .cart-header h2 {
    margin: 0;
    font-size: 1.35rem;
    font-weight: 700;
    color: #00f2fe;
    letter-spacing: 1px;
    text-shadow: 0 0 8px #00f2fe44;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 2.1rem;
    color: #fff;
    cursor: pointer;
    transition: color 0.2s, transform 0.2s;
    border-radius: 50%;
    width: 2.5rem;
    height: 2.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    color: #00f2fe;
    background: rgba(0,242,254,0.08);
    transform: scale(1.12);
  }

  .cart-items {
    flex: 1 1 auto;
    overflow-y: auto;
    padding: 0.5rem 1.5rem 1rem 1.5rem;
    scrollbar-width: thin;
    scrollbar-color: #00f2fe #23272f;
  }

  .cart-items::-webkit-scrollbar {
    width: 8px;
  }

  .cart-items::-webkit-scrollbar-thumb {
    background: linear-gradient(135deg, #00f2fe 30%, #39ff14 100%);
    border-radius: 8px;
  }

  .cart-items::-webkit-scrollbar-track {
    background: #23272f;
  }

  .cart-footer {
    position: sticky;
    bottom: 0;
    left: 0;
    width: 100%;
    background: rgba(24,28,40,0.96);
    border-top: 2px solid #00f2fe;
    box-shadow: 0 -2px 24px 0 #00f2fe22;
    padding: 1.2rem 1.5rem 1.5rem 1.5rem;
    z-index: 2;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .cart-footer h3 {
    margin: 0 0 0.5rem 0;
    color: #fff;
    font-size: 1.2rem;
    font-weight: 600;
    letter-spacing: 0.5px;
  }

  .checkout-btn {
    width: 100%;
    padding: 1rem 0;
    background: linear-gradient(90deg, #00f2fe 0%, #39ff14 100%);
    color: #23272f;
    border: none;
    border-radius: 10px;
    font-size: 1.15rem;
    font-weight: 700;
    letter-spacing: 1px;
    box-shadow: 0 0 16px #00f2fe44, 0 0 32px #39ff1444;
    cursor: pointer;
    transition: background 0.2s, color 0.2s, transform 0.2s, box-shadow 0.2s;
    text-shadow: 0 0 8px #00f2fe44;
  }

  .checkout-btn:hover:not(:disabled) {
    background: linear-gradient(90deg, #39ff14 0%, #00f2fe 100%);
    color: #fff;
    transform: translateY(-2px) scale(1.03);
    box-shadow: 0 0 32px #00f2fe88, 0 0 48px #39ff1488;
  }

  .checkout-btn:disabled {
    background: #23272f;
    color: #888;
    cursor: not-allowed;
    box-shadow: none;
  }

  .empty-cart {
    text-align: center;
    color: #fff;
    margin: 3rem 0 2rem 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1.2rem;
  }

  .empty-cart p {
    font-size: 1.1rem;
    margin-bottom: 0.5rem;
  }

  .empty-cart button {
    background: linear-gradient(90deg, #00f2fe 0%, #39ff14 100%);
    color: #23272f;
    border: none;
    border-radius: 8px;
    padding: 0.7rem 1.5rem;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 0 12px #00f2fe44;
    transition: background 0.2s, color 0.2s, transform 0.2s;
  }

  .empty-cart button:hover {
    background: linear-gradient(90deg, #39ff14 0%, #00f2fe 100%);
    color: #fff;
    transform: scale(1.05);
  }

  /* POS User Search */
  .pos-user-search {
    background: rgba(24,28,40,0.85);
    border-radius: 10px;
    margin: 1rem 1.5rem 1.5rem 1.5rem;
    padding: 1rem 1rem 0.5rem 1rem;
    border: 1.5px solid #00f2fe44;
    box-shadow: 0 0 12px #00f2fe22;
  }

  .pos-user-search label {
    color: #00f2fe;
    font-weight: 600;
    margin-bottom: 0.3rem;
  }

  .pos-user-search input {
    background: rgba(24,28,40,0.92);
    color: #fff;
    border: 1.5px solid #00f2fe44;
    border-radius: 7px;
    padding: 0.7rem 1rem;
    margin-bottom: 0.5rem;
    font-size: 1rem;
    transition: border 0.2s, box-shadow 0.2s;
  }

  .pos-user-search input:focus {
    outline: none;
    border: 1.5px solid #00f2fe;
    box-shadow: 0 0 8px #00f2fe88;
  }

  .user-results {
    background: rgba(24,28,40,0.98);
    border: 1.5px solid #00f2fe44;
    box-shadow: 0 0 8px #00f2fe22;
  }

  .user-results li {
    color: #fff;
    font-size: 1rem;
  }

  .user-select-btn {
    
    font-weight: 500;
    border-radius: 6px;
    transition: background 0.15s, color 0.15s;
    font-size: large;
  }

  .user-select-btn:hover, .user-select-btn:focus {
    background: #00f2fe22;
    color: #39ff14;
  }

  .selected-user {
    background: rgba(0,242,254,0.08);
    color: #00f2fe;
    border: 1.5px solid #00f2fe44;
    box-shadow: 0 0 8px #00f2fe22;
  }

  .selected-customer-info.warning {
    color: #ffb300;
    background: rgba(255, 193, 7, 0.08);
    border: 1.5px solid #ffb30044;
    border-radius: 7px;
    margin-top: 0.5rem;
    padding: 0.7rem 1rem;
  }

  /* Notification */
  .notification {
    padding: 0.75rem 1.2rem;
    margin: 1rem 1.5rem 0 1.5rem;
    border-radius: 8px;
    font-weight: 600;
    font-size: 1rem;
    box-shadow: 0 0 8px #00f2fe22;
    border: 1.5px solid #00f2fe44;
    background: rgba(0,242,254,0.08);
    color: #00f2fe;
  }

  .notification.success {
    background: rgba(39, 255, 20, 0.12);
    color: #39ff14;
    border-color: #39ff1444;
  }

  .notification.error {
    background: rgba(255, 0, 70, 0.12);
    color: #ff0046;
    border-color: #ff004644;
  }

  .loading {
    text-align: center;
    color: #00f2fe;
    padding: 1rem;
    font-weight: 600;
  }

  /* Responsive Styles */
  @media (max-width: 600px) {
    .cart-container {
      width: 100vw;
      max-width: 100vw;
      height: 100vh;
      border-radius: 0;
      border-left: none;
      border-top: 4px solid #00f2fe;
      right: 0;
      left: 0;
      top: auto;
      bottom: 0;
      transform: translateY(100%);
      transition: transform 0.35s cubic-bezier(.77,0,.18,1);
    }
    .cart-container.show {
      transform: translateY(0);
    }
    .cart-header, .cart-footer {
      padding-left: 1rem;
      padding-right: 1rem;
    }
    .cart-footer {
      padding-bottom: 1.2rem;
    }
    .cart-items {
      padding-left: 1rem;
      padding-right: 1rem;
    }
    .pos-user-search {
      margin-left: 1rem;
      margin-right: 1rem;
    }
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

  .user-email {
    color: #888;
    font-size: 0.9em;
  }

  .custom-prices-active {
    margin-top: 0.5rem;
    padding: 0.25rem 0.5rem;
    background: rgba(0, 123, 255, 0.1);
    border-radius: 4px;
    border: 1px solid rgba(0, 123, 255, 0.3);
  }
</style> 