<script lang="ts">
  import { onMount } from 'svelte';
  import type { Product } from '$lib/types';
  import { cartStore, cartNotification } from '$lib/stores/cartStore';
  import { supabase } from '$lib/supabase';
  
  export let product: Product;
  let loading = false;
  let currentStock = product.quantity;
  let displayStock = currentStock; // New variable for display purposes
  let stockStatus = '';
  let selectedQuantity = 1;
  let cardElement: HTMLElement;

  // Subscribe to cart store to track items of this product
  $: cartItemQuantity = $cartStore.find(item => item.id === product.id)?.quantity || 0;
  $: displayStock = currentStock - cartItemQuantity;
  $: updateStockStatus(displayStock);

  // Check current stock level
  async function checkStock() {
    const { data, error } = await supabase
      .from('products')
      .select('quantity')
      .eq('id', product.id)
      .single();

    if (!error && data) {
      currentStock = data.quantity;
      displayStock = currentStock - cartItemQuantity;
      updateStockStatus(displayStock);
    }
  }

  function updateStockStatus(stock: number) {
    if (stock <= 0) {
      stockStatus = 'Out of Stock';
    } else if (stock <= 5) {
      stockStatus = `Low Stock: ${stock} left`;
    } else {
      stockStatus = `In Stock: ${stock} available`;
    }
  }

  onMount(() => {
    checkStock();
  });

  async function handleAddToCart() {
    if (loading) return;
    
    loading = true;
    product.quantity = selectedQuantity;
    const success = await cartStore.addItem(product);
    if (success) {
      // Add animation class to the specific card
      cardElement.classList.add('added-to-cart');
      setTimeout(() => {
        cardElement.classList.remove('added-to-cart');
      }, 700);
      // Reset selected quantity after successful add
      selectedQuantity = 1;
    }
    loading = false;
  }

  function handleQuantityChange(change: number) {
    const newQuantity = selectedQuantity + change;
    // Check against displayStock instead of currentStock
    if (newQuantity >= 1 && newQuantity <= displayStock) {
      selectedQuantity = newQuantity;
    }
  }
</script>

<div 
  class="product-card" 
  bind:this={cardElement}
  tabindex="0" 
  aria-label={`Product: ${product.name}`}
>
  <img 
    src={product.image_url} 
    alt={product.name} 
    class="product-image" 
    loading="lazy"
  />
  <div class="product-info">
    <h3>{product.name}</h3>
    <p>R{product.price}</p>
    
    <div class="stock-status" 
      class:out-of-stock={displayStock <= 0} 
      class:low-stock={displayStock > 0 && displayStock <= 5}
    >
      {stockStatus}
    </div>

    <div class="quantity-controls">
      <button 
        class="quantity-btn" 
        aria-label="Decrease quantity" 
        on:click={() => handleQuantityChange(-1)}
        disabled={selectedQuantity <= 1 || loading || displayStock <= 0}
      >-</button>
      <span class="quantity-display">{selectedQuantity}</span>
      <button 
        class="quantity-btn" 
        aria-label="Increase quantity" 
        on:click={() => handleQuantityChange(1)}
        disabled={selectedQuantity >= displayStock || loading || displayStock <= 0}
      >+</button>
    </div>
    <button 
      on:click={handleAddToCart} 
      class="add-to-cart-btn"
      class:loading
      disabled={loading || displayStock <= 0 || selectedQuantity > displayStock}
      aria-label={`Add ${product.name} to cart`}
    >
      {#if loading}
        Adding...
      {:else if displayStock <= 0}
        Out of Stock
      {:else}
        Add to Cart
      {/if}
    </button>
  </div>
</div>

<style>
  .product-card {
    background: white;
    border-radius: 12px;
    overflow: hidden;
    text-align: center;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    transition: transform 0.2s, box-shadow 0.2s;
    width: 100%;
    margin: 0 auto;
    position: relative;
  }

  @keyframes addToCartSuccess {
    0% {
      transform: translateY(-4px);
      box-shadow: 0 6px 16px rgba(0,0,0,0.12);
    }
    25% {
      transform: translateY(-8px);
    }
    50% {
      transform: translateY(-4px);
    }
    75% {
      transform: translateY(-6px);
    }
    100% {
      transform: translateY(-4px);
      box-shadow: 0 6px 16px rgba(0,0,0,0.12);
    }
  }

  .product-card.added-to-cart::before {
    content: '✓';
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: rgba(40, 167, 69, 0.9);
    color: white;
    width: 60px;
    height: 60px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 2rem;
    animation: checkmarkPop 0.5s ease forwards;
    z-index: 2;
  }

  .product-card.added-to-cart::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.8);
    animation: fadeOut 0.7s ease forwards;
    z-index: 1;
  }

  @keyframes checkmarkPop {
    0% {
      transform: translate(-50%, -50%) scale(0);
      opacity: 0;
    }
    50% {
      transform: translate(-50%, -50%) scale(1.2);
      opacity: 1;
    }
    70% {
      transform: translate(-50%, -50%) scale(0.9);
    }
    100% {
      transform: translate(-50%, -50%) scale(1);
      opacity: 0;
    }
  }

  @keyframes fadeOut {
    0% {
      opacity: 0;
    }
    20% {
      opacity: 1;
    }
    100% {
      opacity: 0;
    }
  }

  .product-card.added-to-cart {
    animation: addToCartSuccess 0.7s ease;
  }

  .product-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 6px 16px rgba(0,0,0,0.12);
  }

  .product-card:focus {
    outline: 2px solid #007bff;
    outline-offset: 2px;
  }

  .product-image {
    
    height: 250px;
    object-fit: cover;
  }

  .product-info {
    padding: 1.25rem;
  }

  .product-info h3 {
    margin: 0.5rem 0;
    font-size: 1.2rem;
    font-weight: 600;
    color: #333;
  }

  .product-info p {
    margin: 0.5rem 0 1.25rem;
    font-size: 1.1rem;
    color: #444;
    font-weight: 500;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1.25rem;
    gap: 0.5rem;
  }

  .quantity-btn {
    background: #f0f0f0;
    border: 1px solid #ddd;
    width: 32px;
    height: 32px;
    border-radius: 6px;
    font-size: 1.2rem;
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

  .quantity-display {
    min-width: 40px;
    font-size: 1.1rem;
    font-weight: 500;
    color: #333;
    text-align: center;
  }

  .stock-status {
    margin: 0.5rem 0;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    font-size: 0.9rem;
    background: #e8f5e9;
    color: #2e7d32;
  }

  .stock-status.out-of-stock {
    background: #ffebee;
    color: #c62828;
  }

  .stock-status.low-stock {
    background: #fff3e0;
    color: #ef6c00;
  }

  .add-to-cart-btn {
    background: #007bff;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 30px;
    font-size: 1.1rem;
    font-weight: 500;
    width: 100%;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .add-to-cart-btn:hover:not(:disabled) {
    background: #0056b3;
  }

  .add-to-cart-btn:disabled {
    background: #ccc;
    cursor: not-allowed;
  }

  .add-to-cart-btn.loading {
    background: #ccc;
    cursor: not-allowed;
  }

  @media (max-width: 1440px) {
    .product-info {
      padding: 1rem;
    }

    .product-info h3 {
      font-size: 1.1rem;
    }

    .product-info p {
      font-size: 1rem;
    }

    .quantity-btn {
      width: 30px;
      height: 30px;
      font-size: 1.1rem;
    }

    .quantity-display {
      font-size: 1rem;
    }

    .add-to-cart-btn {
      font-size: 1rem;
      padding: 8px 16px;
    }
  }

  @media (max-width: 768px) {
    .product-image {
      height: 200px;
    }

    .product-info {
      padding: 0.75rem;
    }

    .product-info h3 {
      font-size: 1rem;
    }

    .product-info p {
      font-size: 0.95rem;
    }

    .quantity-btn {
      width: 28px;
      height: 28px;
      font-size: 1rem;
    }

    .quantity-display {
      font-size: 0.95rem;
    }

    .add-to-cart-btn {
      font-size: 0.95rem;
      padding: 6px 12px;
    }
  }
</style> 