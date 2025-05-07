<script lang="ts">
  import { onMount } from 'svelte';
  import { cartStore } from '$lib/stores/cartStore';
  import { createOrder } from '$lib/services/orderService';
  import { goto } from '$app/navigation';
  import type { CartItem } from '$lib/types';
  import { fade, slide } from 'svelte/transition';
  
  let loading = false;
  let error = '';
  let success = '';
  let paymentMethod = 'cash'; // Default payment method
  
  // Redirect if cart is empty
  $: if ($cartStore.length === 0 && !success) {
    goto('/');
  }
  
  function updateQuantity(item: CartItem, newQuantity: number) {
    cartStore.updateQuantity(item.id, newQuantity);
  }
  
  async function processPayment() {
    if ($cartStore.length === 0) return;
    
    loading = true;
    error = '';
    success = '';
    
    const total = cartStore.getTotal($cartStore);
    console.log('Processing payment for total:', total);
    
    try {
      // Here you would integrate with your payment gateway
      // For now, we'll just simulate a successful payment
      const result = await createOrder(total, $cartStore);
      console.log('Order result:', result);
      
      if (result.success) {
        console.log('Order successful, showing success message');
        success = '🎉 Order placed successfully! Thank you for your purchase.';
        cartStore.clearCart();
        // Show success message for longer and make it more prominent
        setTimeout(() => {
          console.log('Clearing success message and redirecting');
          success = '';
          goto('/');
        }, 5000);
      } else {
        console.log('Order failed:', result.error);
        error = result.error || 'Payment failed. Please try again.';
      }
    } catch (err) {
      console.error('Payment error:', err);
      error = 'An unexpected error occurred. Please try again.';
    } finally {
      loading = false;
    }
  }
</script>

<div class="checkout-container">
  <h1>Checkout</h1>
  
  {#if success}
    <div class="success-overlay" transition:fade>
      <div class="success-message" transition:slide>
        {success}
        <div class="success-icon">✓</div>
      </div>
    </div>
  {/if}
  
  {#if error}
    <div class="error-message">{error}</div>
  {/if}
  
  <div class="checkout-content">
    <div class="order-review">
      <h2>Order Review</h2>
      <div class="cart-items">
        {#each $cartStore as item}
          <div class="cart-item">
            <img src={item.image_url} alt={item.name} />
            <div class="item-details">
              <h3>{item.name}</h3>
              <p class="price">R{item.price} × {item.quantity}</p>
              <div class="quantity-controls">
                <button 
                  class="quantity-btn" 
                  on:click={() => updateQuantity(item, item.quantity - 1)}
                  disabled={item.quantity <= 1}
                >-</button>
                <input
                  type="number"
                  min="1"
                  max="99"
                  class="quantity-input"
                  bind:value={item.quantity}
                  on:change={(e) => updateQuantity(item, Number(e.currentTarget.value))}
                />
                <button 
                  class="quantity-btn" 
                  on:click={() => updateQuantity(item, item.quantity + 1)}
                  disabled={item.quantity >= 99}
                >+</button>
              </div>
            </div>
            <button 
              class="remove-btn"
              on:click={() => cartStore.removeItem(item.id)}
            >×</button>
          </div>
        {/each}
      </div>
    </div>
    
    <div class="payment-section">
      <h2>Payment Method</h2>
      <div class="payment-options">
        <label class="payment-option">
          <input 
            type="radio" 
            name="payment" 
            value="cash" 
            bind:group={paymentMethod}
          />
          <span>Cash on Delivery</span>
        </label>
        <label class="payment-option">
          <input 
            type="radio" 
            name="payment" 
            value="card" 
            bind:group={paymentMethod}
          />
          <span>Credit/Debit Card</span>
        </label>
      </div>
      
      <div class="order-summary">
        <h3>Order Summary</h3>
        <div class="summary-row">
          <span>Subtotal:</span>
          <span>R{cartStore.getTotal($cartStore)}</span>
        </div>
        <div class="summary-row">
          <span>Items:</span>
          <span>{cartStore.getItemCount($cartStore)}</span>
        </div>
      </div>
      
      <button 
        class="pay-button"
        on:click={processPayment}
        disabled={loading || $cartStore.length === 0}
      >
        {#if loading}
          Processing...
        {:else}
          {paymentMethod === 'cash' ? 'Place Order' : 'Pay Now'}
        {/if}
      </button>
    </div>
  </div>
</div>

<style>
  .checkout-container {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1rem;
  }
  
  h1 {
    text-align: center;
    margin-bottom: 2rem;
    color: #333;
  }
  
  .checkout-content {
    display: grid;
    grid-template-columns: 1fr 400px;
    gap: 2rem;
  }
  
  .order-review {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  }
  
  .cart-items {
    margin-top: 1rem;
  }
  
  .cart-item {
    display: flex;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #eee;
  }
  
  .cart-item img {
    width: 80px;
    height: 80px;
    object-fit: cover;
    border-radius: 8px;
    margin-right: 1rem;
  }
  
  .item-details {
    flex-grow: 1;
  }
  
  .item-details h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.1rem;
  }
  
  .price {
    color: #666;
    margin: 0.5rem 0;
  }
  
  .quantity-controls {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .quantity-btn {
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
  
  .quantity-btn:hover:not(:disabled) {
    background: #e0e0e0;
  }
  
  .quantity-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .quantity-input {
    width: 40px;
    padding: 4px;
    border: 1px solid #ccc;
    border-radius: 6px;
    text-align: center;
  }
  
  .remove-btn {
    background: #dc3545;
    color: white;
    border: none;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    font-size: 1.2rem;
    cursor: pointer;
    transition: background-color 0.2s;
    margin-left: 1rem;
  }
  
  .remove-btn:hover {
    background: #bd2130;
  }
  
  .payment-section {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    position: sticky;
    top: 2rem;
  }
  
  .payment-options {
    margin: 1rem 0;
  }
  
  .payment-option {
    display: flex;
    align-items: center;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    margin-bottom: 0.5rem;
    cursor: pointer;
    transition: background-color 0.2s;
  }
  
  .payment-option:hover {
    background: #f8f9fa;
  }
  
  .payment-option input {
    margin-right: 0.75rem;
  }
  
  .order-summary {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #eee;
  }
  
  .summary-row {
    display: flex;
    justify-content: space-between;
    margin: 0.5rem 0;
    color: #666;
  }
  
  .pay-button {
    width: 100%;
    padding: 1rem;
    background: #28a745;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1.1rem;
    cursor: pointer;
    transition: background-color 0.2s;
    margin-top: 1rem;
  }
  
  .pay-button:hover:not(:disabled) {
    background: #218838;
  }
  
  .pay-button:disabled {
    background: #ccc;
    cursor: not-allowed;
  }
  
  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
  }
  
  .success-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    animation: fadeIn 0.3s ease-in;
  }

  .success-message {
    background: white;
    color: #155724;
    padding: 2rem;
    border-radius: 12px;
    font-size: 1.5rem;
    text-align: center;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    max-width: 90%;
    width: 400px;
    position: relative;
    animation: slideIn 0.5s ease-out;
  }

  .success-icon {
    font-size: 3rem;
    color: #28a745;
    margin: 1rem 0;
  }

  @keyframes slideIn {
    from {
      transform: translateY(-20px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }
  
  @media (max-width: 768px) {
    .checkout-content {
      grid-template-columns: 1fr;
    }
    
    .payment-section {
      position: static;
    }
  }
</style> 