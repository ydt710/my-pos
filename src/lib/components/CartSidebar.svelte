<script lang="ts">
  import { tick } from 'svelte';
  import { cartStore } from '$lib/stores/cartStore';
  import type { CartItem } from '$lib/types';
  import { createOrder } from '$lib/services/orderService';
  
  export let visible = false;
  export let toggleVisibility: () => void;
  
  let loading = false;
  let error = '';
  let success = '';
  let cartSidebar: HTMLDivElement;
  
  async function checkout() {
    if ($cartStore.length === 0) return;
    
    loading = true;
    error = '';
    success = '';
    
    const total = cartStore.getTotal($cartStore);
    const result = await createOrder(total, $cartStore);
    
    loading = false;
    
    if (result.success) {
      success = `✅ Sale complete — Total: R${total}`;
      cartStore.clearCart();
      // Close cart after a short delay
      setTimeout(() => {
        visible = false;
        success = '';
      }, 2000);
    } else {
      error = result.error || 'An error occurred during checkout';
    }
  }

  function updateQuantity(item: CartItem, newQuantity: number) {
    cartStore.updateQuantity(item.id, newQuantity);
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
  
  {#if error}
    <div class="error-message">{error}</div>
  {/if}
  
  {#if success}
    <div class="success-message">{success}</div>
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
                disabled={item.quantity <= 1}
              >-</button>
              <input
                type="number"
                min="1"
                max="99"
                class="quantity-input"
                bind:value={item.quantity}
                aria-label="Quantity"
                on:change={(e) => updateQuantity(item, Number(e.currentTarget.value))}
              />
              <button 
                class="quantity-btn" 
                aria-label="Increase quantity" 
                on:click={() => updateQuantity(item, item.quantity + 1)}
                disabled={item.quantity >= 99}
              >+</button>
            </div>
          </div>
          <button 
            on:click={() => cartStore.removeItem(item.id)} 
            class="remove-btn"
            aria-label={`Remove ${item.name} from cart`}
          >×</button>
        </div>
      {/each}
    </div>
    
    <div class="cart-footer">
      <h3>Total: R{cartStore.getTotal($cartStore)}</h3>
      <button 
        on:click={checkout} 
        class="checkout-btn" 
        disabled={$cartStore.length === 0 || loading}
        aria-busy={loading}
      >
        {loading ? 'Processing...' : 'Checkout'}
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
</style> 