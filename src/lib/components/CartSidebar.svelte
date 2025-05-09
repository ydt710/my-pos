<script lang="ts">
  import { tick } from 'svelte';
  import { cartStore, cartNotification } from '$lib/stores/cartStore';
  import type { CartItem } from '$lib/types';
  import { goto } from '$app/navigation';
  
  export let visible = false;
  export let toggleVisibility: () => void;
  
  let loading = false;
  let error = '';
  let success = '';
  let cartSidebar: HTMLDivElement;
  
  function goToCheckout() {
    if ($cartStore.length === 0) return;
    toggleVisibility();
    goto('/checkout');
  }

  async function updateQuantity(item: CartItem, newQuantity: number) {
    loading = true;
    await cartStore.updateQuantity(item.id, newQuantity);
    loading = false;
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
      on:click={() => {
        visible = false;
      }}
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
      {#each $cartStore as item}
        <div class="cart-item">
          <img src={item.image_url} alt={item.name} />
          <div class="cart-item-info">
            <div class="cart-item-name">{item.name}</div>
            <div class="cart-item-price">R{item.price} × {item.quantity}</div>
            <div class="cart-item-quantity">
              <button 
                class="quantity-btn" 
                aria-label="Decrease quantity" 
                on:click={() => updateQuantity(item, item.quantity - 1)}
                disabled={item.quantity <= 1 || loading}
              >-</button>
              <input
                type="number"
                min="1"
                class="quantity-input"
                bind:value={item.quantity}
                aria-label="Quantity"
                disabled={loading}
                on:change={(e) => updateQuantity(item, Number(e.currentTarget.value))}
              />
              <button 
                class="quantity-btn" 
                aria-label="Increase quantity" 
                on:click={() => updateQuantity(item, item.quantity + 1)}
                disabled={loading}
              >+</button>
            </div>
          </div>
          <button 
            on:click={() => cartStore.removeItem(item.id)} 
            class="remove-btn"
            aria-label={`Remove ${item.name} from cart`}
            disabled={loading}
          >×</button>
        </div>
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
  
  .cart-container:focus {
    outline: none;
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
    color: #333;
    padding: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: background-color 0.2s;
  }
  
  .close-btn:hover {
    background: #f5f5f5;
  }
  
  .cart-items {
    flex-grow: 1;
    overflow-y: auto;
    padding-right: 0.5rem;
    margin-right: -0.5rem;
    max-height: calc(60vh - 150px);
  }

  .cart-item {
    display: flex;
    align-items: center;
    margin-bottom: 0.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #f0f0f0;
  }

  .cart-item img {
    width: 45px;
    height: 45px;
    border-radius: 6px;
    margin-right: 0.75rem;
    object-fit: cover;
  }

  .cart-item-info {
    flex-grow: 1;
  }

  .cart-item-name {
    font-weight: 600;
    font-size: 0.95rem;
    margin-bottom: 0.25rem;
  }

  .cart-item-price {
    color: #666;
    font-size: 0.9rem;
  }

  .remove-btn {
    background: #dc3545;
    color: white;
    border: none;
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 0.9rem;
    cursor: pointer;
    transition: background 0.2s;
    margin-left: 1rem;
  }
  
  .remove-btn:hover {
    background: #bd2130;
  }
  
  .cart-footer {
    margin-top: 0.75rem;
    padding-top: 0.75rem;
    border-top: 1px solid #eee;
    position: sticky;
    bottom: 0;
    background: white;
    z-index: 1;
  }

  .cart-footer h3 {
    font-size: 1.1rem;
    margin-bottom: 0.5rem;
  }

  .checkout-btn {
    background: #28a745;
    border: none;
    color: white;
    padding: 8px 16px;
    border-radius: 30px;
    width: 100%;
    font-size: 0.95rem;
    cursor: pointer;
    transition: background 0.2s;
  }
  
  .checkout-btn:hover:not(:disabled) {
    background: #218838;
  }

  .checkout-btn:disabled {
    background: #ccc;
    cursor: not-allowed;
  }
  
  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 12px;
    border-radius: 8px;
    margin-bottom: 1rem;
    font-size: 0.95rem;
  }
  
  .success-message {
    background: #d4edda;
    color: #155724;
    padding: 12px;
    border-radius: 8px;
    margin-bottom: 1rem;
    font-size: 0.95rem;
  }
  
  .empty-cart {
    text-align: center;
    color: #666;
    margin: 2rem 0;
    font-size: 1.1rem;
  }

  /* Custom scrollbar for cart items */
  .cart-items::-webkit-scrollbar {
    width: 4px;
  }

  .cart-items::-webkit-scrollbar-track {
    background: #f1f1f1;
    border-radius: 2px;
  }

  .cart-items::-webkit-scrollbar-thumb {
    background: #888;
    border-radius: 2px;
  }

  .cart-items::-webkit-scrollbar-thumb:hover {
    background: #555;
  }

  .cart-item-quantity {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .cart-item-quantity .quantity-btn {
    background: #f0f0f0;
    border: 1px solid #ddd;
    width: 28px;
    height: 28px;
    border-radius: 6px;
    font-size: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .cart-item-quantity .quantity-btn:hover:not(:disabled) {
    background: #e0e0e0;
  }

  .cart-item-quantity .quantity-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .cart-item-quantity .quantity-input {
    width: 40px;
    padding: 4px;
    border: 1px solid #ccc;
    border-radius: 6px;
    text-align: center;
    font-size: 0.95rem;
  }

  .cart-item-quantity .quantity-input::-webkit-inner-spin-button,
  .cart-item-quantity .quantity-input::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .cart-item-quantity .quantity-input {
    -moz-appearance: textfield;
  }

  @media (max-width: 768px) {
    .cart-container {
      width: 100%;
      height: 50vh;
      max-height: 50vh;
      margin-top: 25vh;
      border-radius: 12px 12px 0 0;
    }

    .cart-items {
      max-height: calc(50vh - 150px);
    }
  }

  .notification {
    padding: 0.75rem;
    margin-bottom: 1rem;
    border-radius: 6px;
    font-size: 0.9rem;
  }

  .notification.error {
    background-color: #fee2e2;
    color: #991b1b;
    border: 1px solid #fecaca;
  }

  .notification.warning {
    background-color: #fef3c7;
    color: #92400e;
    border: 1px solid #fde68a;
  }

  .notification.success {
    background-color: #d1fae5;
    color: #065f46;
    border: 1px solid #a7f3d0;
  }

  .loading {
    text-align: center;
    padding: 0.5rem;
    color: #666;
    font-size: 0.9rem;
  }

  button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  input:disabled {
    background-color: #f3f4f6;
    cursor: not-allowed;
  }
</style> 