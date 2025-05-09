<script lang="ts">
  import { tick } from 'svelte';
  import { cartStore, cartNotification } from '$lib/stores/cartStore';
  import { goto } from '$app/navigation';
  import CartItem from './CartItem.svelte';
  
  export let visible = false;
  export let toggleVisibility: () => void;
  
  let loading = false;
  let cartSidebar: HTMLDivElement;
  
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
    background: white;
    box-shadow: -5px 0 15px rgba(0,0,0,0.1);
    padding: 1rem;
    transform: translateX(100%);
    transition: transform 0.2s ease-out;
    overflow-y: auto;
    z-index: 20;
    display: flex;
    flex-direction: column;
    margin-top: 20vh;
    border-radius: 12px 0 0 12px;
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
    border-bottom: 1px solid #eee;
    position: sticky;
    top: 0;
    background: white;
    z-index: 1;
  }

  .cart-header h2 {
    margin: 0;
    font-size: 1.25rem;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
  }

  .cart-items {
    flex-grow: 1;
    overflow-y: auto;
  }

  .cart-footer {
    margin-top: auto;
    padding-top: 1rem;
    border-top: 1px solid #eee;
  }

  .checkout-btn {
    width: 100%;
    padding: 0.75rem;
    background: #4CAF50;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  .checkout-btn:disabled {
    opacity: 0.7;
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
    border-radius: 4px;
  }

  .notification.success {
    background: #d4edda;
    color: #155724;
  }

  .notification.error {
    background: #f8d7da;
    color: #721c24;
  }

  .loading {
    text-align: center;
    color: #666;
    padding: 1rem;
  }

  @media (max-width: 768px) {
    .cart-container {
      width: 100%;
      height: 50vh;
      max-height: 50vh;
      margin-top: 25vh;
      border-radius: 12px 12px 0 0;
    }
  }
</style> 