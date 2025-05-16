<script lang="ts">
  import { onMount } from 'svelte';
  import type { Product } from '$lib/types';
  import { cartStore, cartNotification } from '$lib/stores/cartStore';
  import { supabase } from '$lib/supabase';
  import { createEventDispatcher } from 'svelte';
  
  export let product: Product;
  let loading = false;
  let currentStock = product.quantity;
  let displayStock = currentStock; // New variable for display purposes
  let stockStatus = '';
  let selectedQuantity = 1;
  let cardElement: HTMLElement;

  // Gradient color arrays for potency bars
  const thcBarColors = ['#4caf50', '#cddc39', '#ffeb3b', '#ff9800', '#f44336'];
  const cbdBarColors = ['#2196f3', '#00bcd4', '#4caf50', '#cddc39', '#ffeb3b'];

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

  // Helper for potency bar (5 bars, 70 mg/g increments)
  function getPotencyBarCount(min?: number, max?: number): number {
    const value = max ?? min ?? 0;
    if (value > 280) return 5;
    if (value > 210) return 4;
    if (value > 140) return 3;
    if (value > 70) return 2;
    if (value > 0) return 1;
    return 0;
  }

  const dispatch = createEventDispatcher();

  function handleCardClick(e: MouseEvent) {
    // Prevent opening modal if clicking on add to cart or quantity controls
    const target = e.target as HTMLElement;
    if (target.closest('.add-to-cart-btn') || target.closest('.quantity-btn')) return;
    dispatch('showdetails', { product });
  }
</script>

<div class="card-product__container" bind:this={cardElement} style="background-image: url('{product.image_url}'); background-size: cover; background-position: center; position: relative;" on:click={handleCardClick}>
  <div class="card-product__body">
    <div class="card-product__body-container cannabis-product">
      <div class="card-product__image">
        <img src={product.image_url} alt={product.name} />
      </div>
      <div class="card-product__details product__details product__details--cannabis">
        <div class="card-product__title">{product.name}</div>
        <div class="product__price-row">
          <span class="product__price">R{product.price}</span>
        </div>
        <div class="product__cannabis-potency">
          <h4 class="product__cannabis-potency-title">THC</h4>
          <div class="product__cannabis-potency-bar">
            {#each Array(5) as _, i}
              <div
                class="product__cannabis-potency-value product__cannabis-potency-value--thc"
                style="background: {i < getPotencyBarCount(product.thc_min, product.thc_max) ? thcBarColors[i] : '#eee'}"
              ></div>
            {/each}
          </div>
          <span class="product__cannabis-potency-unit">{product.thc_min ?? 0}-{product.thc_max ?? 0} mg/g</span>
        </div>
        <div class="product__cannabis-potency">
          <h4 class="product__cannabis-potency-title">CBD</h4>
          <div class="product__cannabis-potency-bar">
            {#each Array(5) as _, i}
              <div
                class="product__cannabis-potency-value product__cannabis-potency-value--cbd"
                style="background: {i < getPotencyBarCount(product.cbd_min, product.cbd_max) ? cbdBarColors[i] : '#eee'}"
              ></div>
            {/each}
          </div>
          <span class="product__cannabis-potency-unit">{product.cbd_min ?? 0}-{product.cbd_max ?? 0} mg/g</span>
        </div>
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
  </div>
</div>

<style>
.card-product__container {
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  overflow: hidden;
  width: 100%;
  max-width: 340px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  position: relative;

}
.card-product__body,
.card-product__body-container,
.card-product__image,
.card-product__details {
  position: relative;
  z-index: 1;
}
.card-product__container::before {
  display: none;
}
.card-product__container::after {
  content: "";
  position: absolute;
  inset: 0;
  background: #fff;
  opacity: 0.85;
  z-index: 0;
  pointer-events: none;
}
.card-product__body {
  padding: 0 1rem 1rem 1rem;
}
.card-product__body-container {
  display: flex;
  flex-direction: column;
  align-items: center;
}
.card-product__image {
  margin-bottom: 1rem;
  position: relative;
}
.card-product__image img {
  width: 120px;
  height: 120px;
  object-fit: cover;
  border-radius: 50%;
  background: #f8f8f8;
  border: 1px solid #eee;
}
.card-product__title {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
  text-align: center;
}
.product__price-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin: 0.5rem 0 1rem 0;
  justify-content: center;
}
.product__price {
  font-size: 1.2rem;
  font-weight: 700;
  color: #222;
}
.product__cannabis-potency {
  margin-bottom: 0.5rem;
}
.product__cannabis-potency-title {
  font-size: 0.95rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}
.product__cannabis-potency-bar {
  display: flex;
  gap: 0.15rem;
  margin-bottom: 0.25rem;
}
.product__cannabis-potency-value {
  width: 22px;
  height: 8px;
  border-radius: 4px;
  background: #eee;
}
.product__cannabis-potency-unit {
  font-size: 0.9rem;
  color: #555;
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
@media (max-width: 600px) {
  .card-product__container {
    max-width: 100%;
  }
  .card-product__body {
    padding: 0 0.5rem 1rem 0.5rem;
  }
}
@keyframes cart-pop {
  0% { transform: scale(1); box-shadow: 0 4px 12px rgba(0,0,0,0.08);}
  50% { transform: scale(1.07); box-shadow: 0 8px 24px rgba(0,0,0,0.16);}
  100% { transform: scale(1); box-shadow: 0 4px 12px rgba(0,0,0,0.08);}
}

.card-product__container.added-to-cart {
  animation: cart-pop 0.7s cubic-bezier(0.34, 1.56, 0.64, 1);
}
</style> 