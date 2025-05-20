<script lang="ts">
  import { onMount } from 'svelte';
  import type { Product } from '$lib/types';
  import { cartStore, cartNotification, isPosOrAdmin } from '$lib/stores/cartStore';
  import { supabase } from '$lib/supabase';
  import { createEventDispatcher } from 'svelte';
  import { getProductReviews, addReview, updateProductRating } from '$lib/services/reviewService';
  import ProductDetailsModal from './ProductDetailsModal.svelte';
  
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
  
  let loading = false;
  let currentStock = product.quantity;
  let displayStock = currentStock;
  let stockStatus = '';
  let selectedQuantity = 1;
  let cardElement: HTMLElement;
  let reviews: Review[] = [];
  let showReviewModal = false;
  let newReview = {
    rating: 5,
    comment: ''
  };
  let submittingReview = false;
  let showDetailsModal = false;
  let userReview: Review | null = null;
  let showSnackbar = false;
  let snackbarMessage = '';
  let snackbarType: 'success' | 'error' = 'success';
  let snackbarTimeout: NodeJS.Timeout;

  // Gradient color arrays for potency bars
  const thcBarColors = ['#4caf50', '#cddc39', '#ffeb3b', '#ff9800', '#f44336'];
  const cbdBarColors = ['#2196f3', '#00bcd4', '#4caf50', '#cddc39', '#ffeb3b'];

  // Subscribe to cart store to track items of this product
  $: cartItemQuantity = $cartStore.find(item => String(item.id) === String(product.id))?.quantity || 0;
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
    if ($isPosOrAdmin) {
      // Show exact quantities for POS/Admin
      if (stock <= 0) {
        stockStatus = 'Out of Stock (0)';
      } else if (stock <= 5) {
        stockStatus = `Low Stock (${stock})`;
      } else {
        stockStatus = `In Stock (${stock})`;
      }
    } else {
      // Show general status for regular users
      if (stock <= 0) {
        stockStatus = 'Out of Stock';
      } else if (stock <= 5) {
        stockStatus = 'Low Stock';
      } else {
        stockStatus = 'In Stock';
      }
    }
  }

  async function loadReviews() {
    reviews = await getProductReviews(String(product.id));
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      userReview = reviews.find(review => review.user_id === user.id) || null;
      if (userReview) {
        newReview = {
          rating: userReview.rating,
          comment: userReview.comment
        };
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

  async function handleReviewSubmit() {
    if (submittingReview) return;
    
    submittingReview = true;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        showMessage('Please sign in to leave a review', 'error');
        return;
      }
      
      if (userReview) {
        // Update existing review
        const updatedReview = await addReview({
          product_id: String(product.id),
          user_id: user.id,
          rating: newReview.rating,
          comment: newReview.comment
        });
        
        if (updatedReview) {
          await updateProductRating(String(product.id));
          await loadReviews();
          showMessage('Review updated successfully!');
          showReviewModal = false;
        }
      } else {
        // Create new review
        const review = await addReview({
          product_id: String(product.id),
          user_id: user.id,
          rating: newReview.rating,
          comment: newReview.comment
        });
        
        if (review) {
          await updateProductRating(String(product.id));
          await loadReviews();
          showMessage('Review submitted successfully!');
          showReviewModal = false;
        }
      }
    } catch (error) {
      console.error('Error submitting review:', error);
      showMessage('Failed to submit review. Please try again.', 'error');
    } finally {
      submittingReview = false;
    }
  }

  onMount(() => {
    checkStock();
    loadReviews();
  });

  async function handleAddToCart() {
    if (loading) return;
    
    loading = true;
    const productToAdd = { 
      ...product,
      quantity: selectedQuantity,
      id: String(product.id), // Convert id to string
      description: product.description || '' // Ensure description is included
    };
    const success = await cartStore.addItem(productToAdd);
    if (success) {
      cardElement.classList.add('added-to-cart');
      setTimeout(() => {
        cardElement.classList.remove('added-to-cart');
      }, 700);
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

  function handleQuantityInput(event: Event) {
    event.stopPropagation();
    const input = event.target as HTMLInputElement;
    const value = parseInt(input.value);
    if (!isNaN(value) && value >= 1 && value <= displayStock) {
      selectedQuantity = value;
    } else {
      // Reset to previous valid value if input is invalid
      input.value = selectedQuantity.toString();
    }
  }

  function handleQuantityBlur(event: Event) {
    event.stopPropagation();
    const input = event.target as HTMLInputElement;
    const value = parseInt(input.value);
    if (isNaN(value) || value < 1) {
      selectedQuantity = 1;
      input.value = '1';
    } else if (value > displayStock) {
      selectedQuantity = displayStock;
      input.value = displayStock.toString();
    }
  }

  function handleQuantityClick(event: MouseEvent) {
    event.stopPropagation();
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

  function handleCardClick(e: MouseEvent | KeyboardEvent) {
    // Only open modal for left click or Enter/Space
    if (e instanceof MouseEvent) {
      const target = e.target as HTMLElement;
      if (target.closest('.add-to-cart-btn') || target.closest('.quantity-btn')) return;
      if (e.button !== 0) return; // Only left click
    } else if (e instanceof KeyboardEvent) {
      if (e.key !== 'Enter' && e.key !== ' ') return;
    }
    showDetailsModal = true;
  }

  // Generate random rating between 3.5 and 5 for demo
  $: if (!product.rating) {
    product.rating = Number((Math.random() * 1.5 + 3.5).toFixed(1));
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
</script>

<div 
  class="card-product__container" 
  bind:this={cardElement} 
  style="background-image: url('{product.image_url}'); background-size: cover; background-position: center; position: relative;" 
  role="button" 
  tabindex="0"
  on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { handleCardClick(e); } }}
>
  <div class="card-product__body">
    <div class="card-product__body-container cannabis-product">
      <div class="card-product__title">{product.name}</div>
      <div class="product__price-row">
        <span class="product__price">R{product.price}</span>
      </div>
      <div class="product__details-row">
        <div 
          class="card-product__image" 
          on:click={handleCardClick} 
          role="button" 
          tabindex="0" 
          on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { handleCardClick(e); } }}
          aria-label="View product details"
        >
          <img src={product.image_url} alt={product.name} />
        </div>
        <div class="card-product__details product__details product__details--cannabis">
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
            <h4 class="product__cannabis-potency-title">THC</h4>
            <div class="product__cannabis-potency-bar">
              {#each Array(5) as _, i}
                <div
                  class="product__cannabis-potency-value product__cannabis-potency-value--thc"
                  style="background: {i < getPotencyBarCount((product as any).thc_min, (product as any).thc_max) ? thcBarColors[i] : '#eee'}"
                ></div>
              {/each}
            </div>
            <span class="product__cannabis-potency-unit">{(product as any).thc_min ?? 0}-{(product as any).thc_max ?? 0} mg/g</span>
          </div>
          <div class="product__cannabis-potency">
            <h4 class="product__cannabis-potency-title">CBD</h4>
            <div class="product__cannabis-potency-bar">
              {#each Array(5) as _, i}
                <div
                  class="product__cannabis-potency-value product__cannabis-potency-value--cbd"
                  style="background: {i < getPotencyBarCount((product as any).cbd_min, (product as any).cbd_max) ? cbdBarColors[i] : '#eee'}"
                ></div>
              {/each}
            </div>
            <span class="product__cannabis-potency-unit">{(product as any).cbd_min ?? 0}-{(product as any).cbd_max ?? 0} mg/g</span>
          </div>
          <div class="stock-status" 
            class:out-of-stock={displayStock <= 0} 
            class:low-stock={displayStock > 0 && displayStock <= 5}
          >
            {stockStatus}
          </div>
          <div 
            class="quantity-controls" 
            on:click={handleQuantityClick}
            role="group"
            aria-label="Product quantity controls"
          >
            <button 
              class="quantity-btn" 
              aria-label="Decrease quantity" 
              on:click|stopPropagation={() => handleQuantityChange(-1)}
              disabled={selectedQuantity <= 1 || loading || displayStock <= 0}
            >-</button>
            <input
              type="number"
              class="quantity-input"
              value={selectedQuantity}
              min="1"
              max={displayStock}
              on:input={handleQuantityInput}
              on:blur={handleQuantityBlur}
              on:click|stopPropagation
              disabled={loading || displayStock <= 0}
              aria-label="Product quantity"
            />
            <button 
              class="quantity-btn" 
              aria-label="Increase quantity" 
              on:click|stopPropagation={() => handleQuantityChange(1)}
              disabled={selectedQuantity >= displayStock || loading || displayStock <= 0}
            >+</button>
          </div>
          <button 
            class="add-to-cart-btn" 
            on:click|stopPropagation={handleAddToCart} 
            disabled={loading || displayStock <= 0}
            aria-label={`Add ${product.name} to cart`}
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
              <span>Add to Cart</span>
            {/if}
          </button>
          <div 
            class="product__rating" 
            role="button" 
            tabindex="0"
            on:click={() => showReviewModal = true}
            on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { showReviewModal = true; } }}
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
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

{#if showReviewModal}
  <div class="review-modal" on:click|stopPropagation>
    <div class="review-modal__content">
      <button 
        class="close-button" 
        on:click={() => showReviewModal = false}
        aria-label="Close review modal"
      >
        ×
      </button>
      <h3>{userReview ? 'Update Your Review' : 'Write a Review'}</h3>
      <div class="rating-input">
        {#each Array(5) as _, i}
          <button 
            class="star-button" 
            on:click={() => newReview.rating = i + 1}
            disabled={submittingReview}
            aria-label={`Rate ${i + 1} out of 5`}
          >
            <span class="star" class:filled={i < newReview.rating}>★</span>
          </button>
        {/each}
      </div>
      <textarea
        bind:value={newReview.comment}
        placeholder="Write your review..."
        rows="4"
        disabled={submittingReview}
        aria-label="Review comment"
      ></textarea>
      <button 
        class="submit-review" 
        on:click={handleReviewSubmit}
        disabled={submittingReview}
        aria-label={userReview ? "Update review" : "Submit review"}
      >
        {#if submittingReview}
          <span class="loading-spinner"></span>
          {userReview ? 'Updating...' : 'Submitting...'}
        {:else}
          {userReview ? 'Update Review' : 'Submit Review'}
        {/if}
      </button>
    </div>
  </div>
{/if}

{#if showDetailsModal}
  <ProductDetailsModal 
    {product} 
    show={showDetailsModal} 
    on:close={() => showDetailsModal = false} 
  />
{/if}

{#if showSnackbar}
  <div class="snackbar" class:error={snackbarType === 'error'} transition:fade>
    {snackbarMessage}
  </div>
{/if}

<style>
.card-product__container {
  border-radius: 16px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  overflow: hidden;
  width: 100%;
  max-width: 340px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  position: relative;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.card-product__container.added-to-cart {
  transform: scale(1.02);
  box-shadow: 0 8px 24px rgba(33, 150, 243, 0.2);
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
  background: #3a3a3a;
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
  text-align: center;
}

.card-product__title {
  font-size: 1.9rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
  text-align: center;
  width: 100%;
  white-space: normal;
  word-wrap: break-word;
  overflow-wrap: break-word;
  hyphens: auto;
  line-height: 1.2;
  padding: 0 0.5rem;
  color: #ffffff;
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
}

.card-product__image {
  margin-bottom: 0;
  position: relative;
  flex: 0 0 120px;
  display: flex;
  justify-content: center;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.card-product__image:hover {
  transform: scale(1.02);
}

.card-product__image:focus {
  outline: 2px solid #2196f3;
  outline-offset: 2px;
}

.card-product__image img {
  width: 120px;
  height: 285px;
  object-fit: cover;
  border-radius: 3%;
  
  border: 1px solid #eee;
}

.card-product__details {
  flex: 1;
  min-width: 0; /* Prevents flex item from overflowing */
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.product__price {
  color: #ffffff;
  font-size: 1.2rem;
  font-weight: 700;
  
}

.product__cannabis-potency {
  margin-bottom: 0.35rem;
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
}

.product__cannabis-potency-title {
  font-size: 0.9rem;
  font-weight: 600;
  margin: 0;
  padding: 0;
  line-height: 1;
}

.product__cannabis-potency-bar {
  display: flex;
  gap: 0.1rem;
  margin: 0.15rem 0;
  justify-content: center;
}

.product__cannabis-potency-value {
  width: 20px;
  height: 7px;
  border-radius: 3px;
  background: #eee;
}

.product__cannabis-potency-unit {
  font-size: 0.85rem;
  color: #555;
}

.stock-status {
  margin: 0.35rem 0;
  padding: 0.2rem 0.4rem;
  border-radius: 4px;
  font-size: 0.85rem;
  background: #e8f5e9;
  color: #2e7d32;
  text-align: center;
  width: 100%;
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
  margin-bottom: 0.75rem;
  gap: 0.35rem;
  width: 100%;
}

.quantity-btn {
  background: #f0f0f0;
  border: 1px solid #ddd;
  width: 28px;
  height: 28px;
  border-radius: 4px;
  font-size: 1.1rem;
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
  width: 50px;
  height: 28px;
  border: 1px solid #ddd;
  border-radius: 4px;
  text-align: center;
  font-size: 1rem;
  font-weight: 500;
  color: #333;
  background: white;
  -webkit-appearance: none;
  -moz-appearance: textfield;
  appearance: none;
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
  background: linear-gradient(135deg, #2196f3, #1976d2);
  color: white;
  border: none;
  padding: 0.6rem 1.2rem;
  border-radius: 8px;
  font-size: 0.95rem;
  font-weight: 500;
  width: 100%;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  box-shadow: 0 2px 4px rgba(33, 150, 243, 0.2);
  position: relative;
  overflow: hidden;
}

.add-to-cart-btn::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 5px;
  height: 5px;
  background: rgba(255, 255, 255, 0.5);
  opacity: 0;
  border-radius: 100%;
  transform: scale(1, 1) translate(-50%);
  transform-origin: 50% 50%;
}

.add-to-cart-btn:active::after {
  animation: ripple 0.6s ease-out;
}

@keyframes ripple {
  0% {
    transform: scale(0, 0);
    opacity: 0.5;
  }
  100% {
    transform: scale(20, 20);
    opacity: 0;
  }
}

.add-to-cart-btn:hover:not(:disabled) {
  background: linear-gradient(135deg, #1976d2, #1565c0);
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
}

.add-to-cart-btn:active:not(:disabled) {
  transform: translateY(0);
  box-shadow: 0 2px 4px rgba(33, 150, 243, 0.2);
}

.add-to-cart-btn:disabled {
  background: #e0e0e0;
  color: #9e9e9e;
  cursor: not-allowed;
  box-shadow: none;
  transform: none;
}

.add-to-cart-btn.loading {
  background: #e0e0e0;
  cursor: not-allowed;
  box-shadow: none;
}

@media (max-width: 600px) {
  .card-product__container {
    max-width: 100%;
  }
  
  .card-product__body {
    padding: 0 0.5rem 1rem 0.5rem;
  }
  
  .card-product__body-container {
    flex-direction: column;
    gap: 0.5rem;
    align-items: center;
  }
  
  .product__details-row {
    flex-direction: column;
    gap: 0.5rem;
    align-items: center;
  }
  
  .card-product__image {
    margin-bottom: 0.5rem;
  }

  .card-product__details {
    width: 100%;
    max-width: 280px;
    margin: 0 auto;
  }

  .card-product__title {
    font-size: 1rem;
    padding: 0 0.25rem;
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
  min-width: 0; /* Prevents flex item from overflowing */
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
  gap: 0.35rem;
  margin: 0.5rem 0 0 0;
  padding: 0.35rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 6px;
  backdrop-filter: blur(4px);
  justify-content: center;
}

.stars {
  display: flex;
  gap: 0.1rem;
}

.star {
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.1));
  transition: transform 0.2s ease;
}

.star:hover {
  transform: scale(1.1);
}

.rating-value {
  font-weight: 600;
  color: #FFD700;
  font-size: 0.85rem;
}

.rating-count {
  color: #ffffff;
  font-size: 0.75rem;
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

.review-modal {
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
}

.review-modal__content {
  position: relative;
  background: white;
  padding: 2rem;
  border-radius: 12px;
  width: 90%;
  max-width: 400px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.review-modal__content h3 {
  font-size: 1.5rem;
  font-weight: 600;
  color: #333;
  margin: 0 0 1rem 0;
  text-align: center;
}

.review-modal__content textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  margin: 1rem 0;
  resize: vertical;
  min-height: 100px;
  font-family: inherit;
  font-size: 1rem;
  line-height: 1.5;
  color: #333;
  background: #f8f9fa;
  transition: border-color 0.2s ease;
}

.review-modal__content textarea:focus {
  outline: none;
  border-color: #2196f3;
  box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
}

.review-modal__content textarea:disabled {
  background: #f0f0f0;
  cursor: not-allowed;
  opacity: 0.7;
}

.submit-review {
  background: linear-gradient(135deg, #2196f3, #1976d2);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  transition: all 0.2s ease;
  width: 100%;
  margin-top: 1rem;
}

.submit-review:hover:not(:disabled) {
  background: linear-gradient(135deg, #1976d2, #1565c0);
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
}

.submit-review:active:not(:disabled) {
  transform: translateY(0);
  box-shadow: 0 2px 4px rgba(33, 150, 243, 0.2);
}

.submit-review:disabled {
  background: #e0e0e0;
  cursor: not-allowed;
  box-shadow: none;
  transform: none;
}

.loading-spinner {
  width: 20px;
  height: 20px;
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

.rating-input {
  display: flex;
  gap: 0.5rem;
  margin: 1rem 0;
  justify-content: center;
}

.star-button {
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  font-size: 2rem;
  color: #E0E0E0;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.star-button:hover:not(:disabled) {
  transform: scale(1.2);
}

.star-button:disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

.star {
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.1));
  transition: transform 0.2s ease;
}

.star.filled {
  color: #FFD700;
}

.close-button {
  position: absolute;
  top: 1rem;
  right: 1rem;
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #666;
  padding: 0.5rem;
  border-radius: 50%;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}

.close-button:hover {
  background-color: rgba(0, 0, 0, 0.1);
  transform: scale(1.1);
}

.close-button:active {
  transform: scale(0.95);
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
  z-index: 10000;
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
</style> 