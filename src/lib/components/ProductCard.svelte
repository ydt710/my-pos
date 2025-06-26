<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { fade } from 'svelte/transition';
  import type { Product } from '$lib/types/index';
  import { cartStore, cartNotification, isPosOrAdmin, selectedPosUser, getEffectivePrice, customPrices, openCart } from '$lib/stores/cartStore';
  import { supabase } from '$lib/supabase';
  import { createEventDispatcher } from 'svelte';
  import { getProductReviews, addReview, updateProductRating } from '$lib/services/reviewService';
  import { getStock } from '$lib/services/stockService';
  import { get } from 'svelte/store';
  import { debounce, getBalanceColor } from '$lib/utils';
  import { showSnackbar as showGlobalSnackbar } from '$lib/stores/snackbarStore';

  
  interface Review {
    id: string;
    product_id: string;
    user_id: string;
    rating: number;
    comment: string;
    created_at: string;
  }
  
  export let product: Product & { 
    rating?: number;
    indica?: number;
    average_rating?: number;
    review_count?: number;
    description?: string;
  };
  
  export let stock: number = 0;
  
  let loading = false;
  let currentStock = 0;
  let displayStock = 0;
  let stockStatus = '';
  let selectedQuantity = 1;
  let cardElement: HTMLElement | null = null;
  let reviews: Review[] = [];
  let showSnackbar = false;
  let snackbarMessage = '';
  let snackbarType: 'success' | 'error' = 'success';
  let snackbarTimeout: ReturnType<typeof setTimeout>;
  let imageLoaded = false;
  let addToCartInProgress = false;

  // Gradient color arrays for potency bars
  const thcBarColors = ['#4caf50', '#cddc39', '#ffeb3b', '#ff9800', '#f44336'];
  const cbdBarColors = ['#2196f3', '#00bcd4', '#4caf50', '#cddc39', '#ffeb3b'];

  // Subscribe to cart store to track items of this product
  $: cartItemQuantity = $cartStore.find(item => String(item.id) === String(product.id))?.quantity || 0;
  $: displayStock = stock - cartItemQuantity;
  $: updateStockStatus(displayStock);

  // Get selected POS user (for custom pricing)
  $: posUser = $selectedPosUser;
  $: effectivePrice = getEffectivePrice({ ...product, id: String(product.id), description: product.description || '', indica: typeof product.indica === 'number' ? product.indica : 0 }, posUser?.id);
  $: customPricesValue = $customPrices;
  $: hasCustomPrice = posUser && customPricesValue[product.id] && customPricesValue[product.id] !== product.price;

  // ARIA live region for dynamic feedback
  let liveMessage = '';
  $: if (showSnackbar) liveMessage = snackbarMessage;

  function updateStockStatus(stock: number) {
    // Check if product is manually marked as out of stock
    if (product.is_out_of_stock) {
      stockStatus = 'Out of Stock';
      return;
    }

    const lowStockBuffer = product.low_stock_buffer ?? 1000;
    
    if ($isPosOrAdmin) {
      // Show exact quantities for POS/Admin
      if (stock <= 0) {
        stockStatus = 'Out of Stock (0)';
      } else if (lowStockBuffer > 0 && stock <= lowStockBuffer) {
        stockStatus = `Low Stock (${stock})`;
      } else {
        stockStatus = `In Stock (${stock})`;
      }
    } else {
      // Show general status for regular users
      if (stock <= 0) {
        stockStatus = 'Out of Stock';
      } else if (lowStockBuffer > 0 && stock <= lowStockBuffer) {
        stockStatus = 'Low Stock';
      } else {
        stockStatus = 'In Stock';
      }
    }
  }

  function showMessage(message: string, type: 'success' | 'error' = 'success') {
    snackbarMessage = message;
    snackbarType = type;
    showSnackbar = true;
    
    // Clear any existing timeout
    if (snackbarTimeout) {
      clearTimeout(snackbarTimeout);
    }
    
    // Hide snackbar after 3 seconds
    snackbarTimeout = setTimeout(() => {
      showSnackbar = false;
    }, 3000);
  }

  async function handleAddToCart() {
    if (loading || addToCartInProgress) return;
    addToCartInProgress = true;
    loading = true;
    const productToAdd: Product & { quantity: number } = {
      ...product,
      id: String(product.id),
      description: product.description || '',
      indica: typeof product.indica === 'number' ? product.indica : 0,
      quantity: selectedQuantity
    };
    const success = await cartStore.addItem(productToAdd);
    if (success) {
      if (cardElement) cardElement.classList.add('added-to-cart');
      setTimeout(() => {
        if (cardElement) cardElement.classList.remove('added-to-cart');
      }, 700);
      
      // Show global snackbar with cart open option instead of auto-opening cart
      const quantityText = selectedQuantity === 1 ? '' : ` (${selectedQuantity})`;
      showGlobalSnackbar(`${product.name}${quantityText} added to cart! Click here to view cart.`, 4000, openCart);
      
      selectedQuantity = 1;
      // Don't dispatch addToCart anymore since we're not auto-opening the cart
    }
    loading = false;
    addToCartInProgress = false;
  }

  function handleQuantityChange(change: number) {
    const newQuantity = selectedQuantity + change;
    if (newQuantity > displayStock) {
      showMessage(`Cannot add more than available stock (${displayStock}).`, 'error');
      return;
    }
    if (newQuantity >= 1 && newQuantity <= displayStock) {
      selectedQuantity = newQuantity;
    }
  }

  function handleQuantityInput(event: Event) {
    event.stopPropagation();
    const input = event.target as HTMLInputElement;
    const value = input.value;

    // Allow empty value while typing
    if (value === '') {
      return;
    }

    const numberValue = parseInt(value);
    if (numberValue > displayStock) {
      showMessage(`Cannot add more than available stock (${displayStock}).`, 'error');
      input.value = displayStock.toString();
      selectedQuantity = displayStock;
      return;
    }
    if (!isNaN(numberValue) && numberValue >= 1 && numberValue <= displayStock) {
      selectedQuantity = numberValue;
    }
  }

  function handleQuantityBlur(event: Event) {
    const input = event.target as HTMLInputElement;
    const value = input.value;

    const numberValue = parseInt(value);
    if (value === '' || isNaN(numberValue) || numberValue < 1) {
      // Reset to previous valid quantity if left empty or invalid
      input.value = selectedQuantity.toString();
    }
  }

  function handleQuantityClick(event: MouseEvent) {
    event.stopPropagation();
  }

  function handleQuantityKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !loading && displayStock > 0) {
      event.preventDefault();
      handleAddToCart();
    }
  }

  // Helper for potency bar (5 bars, 70 mg/g increments)
  function getPotencyBarCount(max?: number): number {
    const value = max ?? 0;
    if (value > 280) return 5;
    if (value > 210) return 4;
    if (value > 140) return 3;
    if (value > 70) return 2;
    if (value > 0) return 1;
    return 0;
  }

  const dispatch = createEventDispatcher();

  function handleCardClick(e: MouseEvent | KeyboardEvent) {
    // Only open modal for left click or Enter/Space
    if (e instanceof MouseEvent) {
      const target = e.target as HTMLElement;
      if (target.closest('.add-to-cart-btn') || target.closest('.quantity-btn')) return;
      if (e.button !== 0) return; // Only left click
    } else if (e instanceof KeyboardEvent) {
      if (e.key !== 'Enter' && e.key !== ' ') return;
    }
    dispatch('showDetails', { product });
  }

  function getStarColor(index: number, rating: number): string {
    const fullStar = Math.floor(rating);
    const hasHalfStar = rating % 1 >= 0.5;
    
    if (index < fullStar) return '#FFD700'; // Full star
    if (index === fullStar && hasHalfStar) return '#FFD700'; // Half star
    return '#E0E0E0'; // Empty star
  }

  function getStarPath(index: number, rating: number): string {
    const fullStar = Math.floor(rating);
    const hasHalfStar = rating % 1 >= 0.5;
    
    if (index < fullStar) return 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z';
    if (index === fullStar && hasHalfStar) return 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77V2z';
    return 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z';
  }

  function handleAddToCartClick() {
    handleAddToCart();
  }
  function handleQuantityDecrease() {
    handleQuantityChange(-1);
  }
  function handleQuantityIncrease() {
    handleQuantityChange(1);
  }
  function handleQuantityInputChange(event: Event) {
    handleQuantityInput(event);
  }
  function handleQuantityInputBlur(event: Event) {
    handleQuantityBlur(event);
  }
  function handleQuantityInputKeydown(event: KeyboardEvent) {
    handleQuantityKeydown(event);
  }
  function handleQuantityInputClick(event: MouseEvent) {
    handleQuantityClick(event);
  }

  onDestroy(() => {
    // Explicitly clear all timers and references to prevent memory leaks.
    // This is critical for components that are frequently created and destroyed.
    clearTimeout(snackbarTimeout);

    // Nullifying DOM element references can help the garbage collector.
    cardElement = null;
  });
</script>

<div class="card-product__border" class:trippy={product.is_special || product.is_new}>
  <div 
    class="card-product__container" 
    bind:this={cardElement} 
    style="background-image: url('{product.image_url}'); background-size: cover; background-position: center; position: relative;" 
    role="article"
    aria-label="Product card for {product.name}"
  >
    {#if product.is_special}
      <div class="product-badge special">Special</div>
    {:else if product.is_new}
      <div class="product-badge new">New</div>
    {/if}
    <div class="card-product__body">
      <div class="card-product__body-container cannabis-product">
        <div class="card-product__title">{product.name}</div>
        
        <div class="product__details-row">
          <button 
            class="card-product__image" 
            on:click={handleCardClick}
            on:keydown={e => e.key === 'Enter' && handleCardClick(e)}
            aria-label="View product details"
          >
            <div class="card-product__image-aspect">
              {#if !imageLoaded}
                <div class="image-skeleton"></div>
              {/if}
              <img 
                src={product.image_url + '?width=300&quality=75'} 
                srcset="
                  {product.image_url}?width=300&quality=75 300w,
                  {product.image_url}?width=400&quality=75 400w,
                  {product.image_url}?width=500&quality=75 500w
                "
                sizes="
                  (max-width: 480px) 300px,
                  (max-width: 800px) 400px,
                  500px
                "
                alt={product.name}
                loading="lazy"
                decoding="async"
                width="300"
                height="400"
                style="aspect-ratio: 3/4;"
                on:load={() => imageLoaded = true}
                on:error={() => imageLoaded = true}
              />
            </div>
          </button>
          <div class="card-product__details product__details product__details--cannabis">
                <div class="product__price-row">
              {#if hasCustomPrice}
                <span class="product__price">R{effectivePrice}</span>
                <span class="custom-price-label" style="color:#007bff;font-size:0.85em;margin-left:0.5em;">Custom Price</span>
              {:else if product.is_special && product.special_price}
                <span class="product__price" style="text-decoration: line-through; color: #888;">R{product.price}</span>
                <span class="product__price" style="color: #e67e22; font-weight: bold; margin-left: 0.5em;">R{product.special_price}</span>
              {:else}
                <span class="product__price">R{effectivePrice}</span>
                {#if posUser && effectivePrice !== product.price}
                  <span class="custom-price-label" style="color:#007bff;font-size:0.85em;margin-left:0.5em;">Custom Price</span>
                {/if}
              {/if}
            </div>
            {#if product.category !== 'headshop'}
            <div class="product__strain-type">
              <div class="strain-type__labels">
                <span class="strain-type__label">{(100 - (product.indica ?? 0))}% Sativa</span>
                <span class="strain-type__label">{product.indica ?? 0}% Indica</span>
              </div>
              <div class="strain-type__bar">
                <div 
                  class="strain-type__indicator" 
                  style="left: {product.indica ?? 0}%"
                  title="{product.indica ?? 0}% Indica, {(100 - (product.indica ?? 0))}% Sativa"
                ></div>
              </div>
            </div>
            <div class="product__cannabis-potency">
              <h4 class="product__cannabis-potency-title">
                THC
                <span class="product__cannabis-potency-unit">
                  {#if (product as any).thc_max !== undefined}
                    {Math.round((product as any).thc_max * 0.1 * 100) / 100}%
                  {:else}
                    0%
                  {/if}
                </span>
              </h4>
              <div class="product__cannabis-potency-bar">
                {#each Array(5) as _, i}
                  <div
                    class="product__cannabis-potency-value product__cannabis-potency-value--thc"
                    style="background: {i < getPotencyBarCount((product as any).thc_max) ? thcBarColors[i] : '#eee'}"
                  ></div>
                {/each}
              </div>
            </div>
            {/if}
            
            <div class="stock-status" 
              class:out-of-stock={displayStock <= 0} 
              class:low-stock={displayStock > 0 && displayStock <= 1000}
            >
              {stockStatus}
            </div>
            <div
               
              class="quantity-controls" 
              
              role="group"
              aria-label="Product quantity controls"
              
            >
              <button 
                class="quantity-btn" 
                aria-label="Decrease quantity" 
                on:click|stopPropagation={handleQuantityDecrease}
                disabled={selectedQuantity <= 1 || loading || displayStock <= 0}
              >-</button>
              <input
                type="number"
                class="quantity-input"
                value={selectedQuantity}
                min="1"
                max={displayStock}
                on:input={handleQuantityInputChange}
                on:blur={handleQuantityInputBlur}
                on:keydown={handleQuantityInputKeydown}
                on:click|stopPropagation
                disabled={loading || displayStock <= 0}
                aria-label="Product quantity"
              />
              <button 
                class="quantity-btn" 
                aria-label="Increase quantity" 
                on:click|stopPropagation={handleQuantityIncrease}
                disabled={selectedQuantity >= displayStock || loading || displayStock <= 0}
              >+</button>
            </div>
            <button 
              class="add-to-cart-btn" 
              on:click|stopPropagation={handleAddToCartClick}
              disabled={loading || displayStock <= 0}
              aria-label="Add {product.name} to cart"
            >
              {#if loading}
                <span class="loading-spinner" aria-hidden="true"></span>
                <span>Adding...</span>
              {:else if displayStock <= 0}
                <span>Out of Stock</span>
              {:else}
                <svg 
                  xmlns="http://www.w3.org/2000/svg" 
                  width="16" 
                  height="16" 
                  viewBox="0 0 24 24" 
                  fill="none" 
                  stroke="currentColor" 
                  stroke-width="2" 
                  stroke-linecap="round" 
                  stroke-linejoin="round"
                  aria-hidden="true"
                >
                  <circle cx="9" cy="21" r="1"></circle>
                  <circle cx="20" cy="21" r="1"></circle>
                  <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
                </svg>
                
              {/if}
            </button>
            <button 
              class="product__rating" 
              on:click={() => dispatch('showReview', { product })}
              on:keydown={e => e.key === 'Enter' && dispatch('showReview', { product })}
              aria-label="View product reviews"
            >
              <div class="stars" aria-hidden="true">
                {#each Array(5) as _, i}
                  <svg 
                    class="star" 
                    viewBox="0 0 24 24" 
                    width="16" 
                    height="16"
                    style="fill: {getStarColor(i, product.average_rating ?? 0)}"
                  >
                    <path d={getStarPath(i, product.average_rating ?? 0)} />
                  </svg>
                {/each}
              </div>
              <span class="rating-value" aria-label="Average rating: {product.average_rating?.toFixed(1) ?? '0.0'} out of 5">
                {product.average_rating?.toFixed(1) ?? '0.0'}
              </span>
              <span class="rating-count" aria-label="{product.review_count ?? 0} reviews">
                ({product.review_count ?? 0})
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ARIA live region for dynamic feedback -->
<div aria-live="polite" class="sr-only" style="position:absolute;left:-9999px;">{liveMessage}</div>

{#if showSnackbar}
  <div class="snackbar" class:error={snackbarType === 'error'} transition:fade>
    {snackbarMessage}
  </div>
{/if}

<style>
.card-product__border {
  padding: 4px;
  border-radius: 16px;
  display: flex;
  width: 100%;
  max-width: 288px;
  margin: 0 auto;
  
  
  position: relative;
  overflow: hidden;
}
.card-product__border.trippy::before {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: conic-gradient(#ff00de, #00f0ff, #39ff14, #fcdd43, #ff00de);
  animation: trippy-spin 4s linear infinite;
}

@keyframes trippy-spin {
  to { transform: rotate(360deg); }
}

.card-product__border.trippy {
  box-shadow: 0 0 16px #00f0ff, 0 0 32px #ff00de;
}
.card-product__container {
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  overflow: hidden;
  width: 100%;
  max-width: 280px;
  display: flex;
  flex-direction: column;
  position: relative;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
  cursor: default;
  z-index: 1;
  height: 100%;
  margin: 0;
}

.card-product__container::after {
  content: "";
  position: absolute;
  inset: 0;
  background: #3a3a3a;
  opacity: 0.85;
  z-index: 0;
  pointer-events: none;
}

.card-product__body,
.card-product__body-container,
.card-product__image,
.card-product__details {
  position: relative;
  z-index: 1;
}

.card-product__body {
  padding: 0 0.75rem 0.75rem 0.75rem;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.card-product__body-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  height: 100%;
}

.card-product__title {
  font-size: 1.4rem;
  font-weight: 600;
  margin-bottom: 0.35rem;
  text-align: center;
  width: 100%;
  
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  
  line-height: 1.3;
  height: calc(1.4rem * 1.3 * 2);
  min-height: calc(1.4rem * 1.3 * 2);
  
  padding: 0 0.35rem;
  color: #ffffff;
  
  word-break: keep-all;
  hyphens: none;
}

.product__price-row {
  display: flex;
  align-items: center;
  justify-content: center;
  
  width: 100%;
}

.product__details-row {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  flex: 1;
}

.card-product__image {
  margin-bottom: 0;
  position: relative;
  flex: 0 0 100px;
  display: flex;
  justify-content: center;
  cursor: pointer;
  transition: transform 0.2s ease;
  background: none;
  border: none;
  padding: 0;
}

.card-product__image:hover {
  transform: scale(1.02);
}

.card-product__image:focus {
  outline: 2px solid #2196f3;
  outline-offset: 2px;
}

.card-product__image img {
  width: 100px;
  height: 240px;
  object-fit: cover;
  border-radius: 3%;
  border: 1px solid #eee;
}

.card-product__details {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  justify-content: space-between;
  
}

.product__price {
  color: #ffffff;
  font-size: 1.5rem;
  font-weight: 700;
}

.product__cannabis-potency {
  margin-bottom: 0.25rem;
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.1rem;
  
}

.product__cannabis-potency-title {
  font-size: 0.8rem;
  font-weight: 600;
  margin: 0;
  padding: 0;
  line-height: 1;
}

.product__cannabis-potency-bar {
  display: flex;
  gap: 0.1rem;
  margin: 0.1rem 0;
  justify-content: center;
}

.product__cannabis-potency-value {
  width: 26px;
  height: 9px;
  border-radius: 2px;
  background: #eee;
}

.product__cannabis-potency-unit {
  font-size: 0.75rem;
  color: #fff;
}

.stock-status {
  margin: 0.25rem 0;
  padding: 0.15rem 0.3rem;
  border-radius: 4px;
  font-size: 0.9rem;
  background: #e8f5e9;
  color: #2e7d32;
  text-align: center;
  min-height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
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
  margin-bottom: 0.5rem;
  gap: 0.25rem;
  width: 100%;
  min-height: 32px;
}

.quantity-btn {
  background: #f0f0f0;
  border: 1px solid #ddd;
  width: 24px;
  height: 24px;
  border-radius: 4px;
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
  height: 24px;
  border: 1px solid #ddd;
  border-radius: 4px;
  text-align: center;
  font-size: 0.9rem;
  font-weight: 500;
  color: #333;
  background: white;
}

.quantity-input::-webkit-outer-spin-button,
.quantity-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.quantity-input:disabled {
  background: #f0f0f0;
  color: #999;
  cursor: not-allowed;
}

.add-to-cart-btn {
  background: linear-gradient(77deg, hsl(195.35deg 67.65% 41.89%), #00deff, #14ffbd);
  color: #fff;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.95rem;
  font-weight: 600;
  width: 100%;
  cursor: pointer;
  transition: background 0.3s, color 0.3s, transform 0.3s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  text-shadow: 0 0 8px #00f0ff, 0 0 16px #ff00de;
  letter-spacing: 0.5px;
  min-height: 44px;
  margin-top: auto;
}

/* @keyframes trippy-gradient {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
} */

.add-to-cart-btn:hover:not(:disabled),
.add-to-cart-btn:focus-visible {
  /* box-shadow: 0 0 24px #00f0ff, 0 0 48px #ff00de, 0 0 64px #39ff14; */
  /* text-shadow: 0 0 16px #00f0ff, 0 0 32px #ff00de; */
  outline: 2px solid #fff;
  outline-offset: 2px;
  transform: scale(1.05);
}

.add-to-cart-btn:active:not(:disabled) {
  /* box-shadow: 0 0 8px #00f0ff, 0 0 16px #ff00de; */
  transform: scale(0.98);
}

.add-to-cart-btn:disabled {
  background: #222b2b;
  color: #9e9e9e;
  cursor: not-allowed;
  box-shadow: none;
  text-shadow: none;
  transform: none;
}

.add-to-cart-btn:focus-visible {
  outline: 2px solid #fff;
  outline-offset: 2px;
}

@media (max-width: 600px) {
  .card-product__border {
    border-radius: 14px;
    max-width: 100%;
    padding: 4px;
    min-height: 380px;
    height: 380px;
  }
  .card-product__container {
    max-width: 100%;
    border-radius: 10px;
  }
  
  .card-product__body {
    padding: 0 0.5rem 0.75rem 0.5rem;
  }
  
  .card-product__body-container {
    flex-direction: column;
    gap: 0.5rem;
    align-items: center;
  }
  
  .product__details-row {
    flex-direction: row;
    gap: 0.5rem;
    align-items: flex-start;
  }
  
  .card-product__image {
    margin-bottom: 0.5rem;
  }

  .card-product__image img {
    height: 180px;
  }

  .card-product__details {
    width: 100%;
    max-width: 280px;
    margin: 0 auto;
  }

  .card-product__title {
    font-size: 1.2rem;
    padding: 0 0.25rem;
    height: calc(1.2rem * 1.3 * 2);
    min-height: calc(1.2rem * 1.3 * 2);
  }
}

@keyframes cart-pop {
  0% { 
    transform: scale(1); 
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  }
  50% { 
    transform: scale(1.02); 
    box-shadow: 0 8px 24px rgba(33, 150, 243, 0.2);
  }
  100% { 
    transform: scale(1); 
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  }
}

.product__strain-type {
  width: 100%;
  margin-bottom: 0.5rem;
  padding: 0 0.25rem;
  min-width: 0;
}

.strain-type__labels {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.15rem;
  font-size: 0.85rem;
  color: #ffffff;
}

.strain-type__bar {
  position: relative;
  height: 10px;
  background: linear-gradient(to right, #fcdd43, #000000);
  border-radius: 3px;
  overflow: hidden;
}

.strain-type__indicator {
  position: absolute;
  top: 0;
  width: 2px;
  height: 100%;
  background: white;
  box-shadow: 0 0 4px rgba(0,0,0,0.3);
  transform: translateX(-50%);
  transition: left 0.3s ease;
}

.loading-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid #ffffff;
  border-radius: 50%;
  border-top-color: transparent;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.product__rating {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  margin: 0.35rem 0 0 0;
  padding: 0.25rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 4px;
  backdrop-filter: blur(4px);
  justify-content: center;
  border: none;
  cursor: pointer;
  width: 100%;
  min-height: 32px;
}

.product__rating:hover {
  background: rgba(255, 255, 255, 0.15);
}

.product__rating:focus-visible {
  outline: 2px solid #2196f3;
  outline-offset: 2px;
}

.stars {
  display: flex;
  gap: 0.1rem;
}

.star {
  width: 14px;
  height: 14px;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.1));
}

.star:hover {
  transform: scale(1.1);
}

.rating-value {
  font-weight: 600;
  color: #FFD700;
  font-size: 0.75rem;
}

.rating-count {
  color: #ffffff;
  font-size: 0.7rem;
  opacity: 0.8;
}

@media (max-width: 600px) {
  .product__rating {
    padding: 0.25rem;
    margin: 0.35rem 0 0 0;
  }
  
  .star {
    width: 14px;
    height: 14px;
  }
  
  .rating-value {
    font-size: 0.8rem;
  }
  
  .rating-count {
    font-size: 0.7rem;
  }
}

.snackbar {
  position: fixed;
  bottom: 2rem;
  left: 50%;
  transform: translateX(-50%);
  background: #4CAF50;
  color: white;
  padding: 1rem 2rem;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  z-index: 10;
  font-weight: 500;
  animation: slideUp 0.3s ease-out;
}

.snackbar.error {
  background: #f44336;
}

@keyframes slideUp {
  from {
    transform: translate(-50%, 100%);
    opacity: 0;
  }
  to {
    transform: translate(-50%, 0);
    opacity: 1;
  }
}

@keyframes fade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.product-badge {
  position: absolute;
  top: 10px;
  left: 10px;
  z-index: 2;
  padding: 0.25rem 0.75rem;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 700;
  color: #fff;
  background: #2196f3;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  letter-spacing: 1px;
}

.product-badge.special {
  background: #ff00de;
}

.product-badge.new {
  background: #39ff14;
  color: #23272f;
}

.card-product__image-aspect {
  width: 100px;
  aspect-ratio: 3/4;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}
.image-skeleton {
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, #222 25%, #333 50%, #222 75%);
  background-size: 200% 100%;
  animation: skeleton-loading 1.2s infinite linear;
  border-radius: 3%;
  position: absolute;
  top: 0;
  left: 0;
  z-index: 1;
}
@keyframes skeleton-loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
</style> 