<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Product } from '$lib/types/index';
  import { getProductReviews, addReview, updateReview, updateProductRating } from '$lib/services/reviewService';
  import { supabase } from '$lib/supabase';
  import { getProductImage } from '$lib/constants';
  
  interface Review {
    id: string;
    product_id: string;
    user_id: string;
    rating: number;
    comment: string;
    created_at: string;
    user?: {
      email?: string;
      display_name?: string;
    };
  }
  
  export let product: Product & {
    description?: string;
    sativa?: number;
    indica?: number;
    thc_min?: number;
    thc_max?: number;
    cbd_min?: number;
    cbd_max?: number;
    average_rating?: number;
    review_count?: number;
  };
  export let show = false;
  export let stock: number = 0;
  let selectedQuantity = 1;
  let loading = false;
  
  let reviews: Review[] = [];
  let newReview = {
    rating: 5,
    comment: ''
  };
  let submittingReview = false;
  let userReview: Review | null = null;
  
  const dispatch = createEventDispatcher();
  
  // Color arrays for potency bars
  const thcBarColors = ['#4caf50', '#cddc39', '#ffeb3b', '#ff9800', '#f44336'];
  const cbdBarColors = ['#2196f3', '#00bcd4', '#4caf50', '#cddc39', '#ffeb3b'];
  
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
  
  async function handleReviewSubmit() {
    if (submittingReview) return;
    
    submittingReview = true;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        alert('Please sign in to leave a review');
        return;
      }
      
      if (userReview) {
        // Update existing review
        const updatedReview = await updateReview(userReview.id, {
          rating: newReview.rating,
          comment: newReview.comment
        });
        
        if (updatedReview) {
          await updateProductRating(String(product.id));
          await loadReviews();
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
        }
      }
    } catch (error) {
      console.error('Error submitting review:', error);
      alert('Failed to submit review. Please try again.');
    } finally {
      submittingReview = false;
    }
  }
  
  function handleClose() {
    dispatch('close');
  }
  
  function handleBackdropClick(e: MouseEvent) {
    if (e.target === e.currentTarget) {
      handleClose();
    }
  }
  
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      handleClose();
    }
  }
  
  function handleQuantityChange(change: number) {
    const newQuantity = selectedQuantity + change;
    if (newQuantity > stock) return;
    if (newQuantity >= 1 && newQuantity <= stock) {
      selectedQuantity = newQuantity;
    }
  }
  function handleQuantityInput(event: Event) {
    const input = event.target as HTMLInputElement;
    const value = input.value;
    if (value === '') return;
    const numberValue = parseInt(value);
    if (numberValue > stock) {
      input.value = stock.toString();
      selectedQuantity = stock;
      return;
    }
    if (!isNaN(numberValue) && numberValue >= 1 && numberValue <= stock) {
      selectedQuantity = numberValue;
    }
  }
  function handleQuantityBlur(event: Event) {
    const input = event.target as HTMLInputElement;
    const value = input.value;
    const numberValue = parseInt(value);
    if (value === '' || isNaN(numberValue) || numberValue < 1) {
      input.value = selectedQuantity.toString();
    }
  }
  async function handleAddToCart() {
    if (loading || stock <= 0) return;
    loading = true;
    dispatch('addToCart', { product, quantity: selectedQuantity });
    loading = false;
    selectedQuantity = 1;
  }
  
  $: if (show) {
    loadReviews();
  }
</script>

<div 
  class="modal-backdrop" 
  role="dialog"
  aria-modal="true"
  aria-labelledby="modal-title"
  tabindex="-1"
  on:click={handleBackdropClick}
  on:keydown={handleKeydown}
>
  <div class="modal-content" role="document">
    <div class="modal-header">
      <h2 id="modal-title" tabindex="-1">{product.name || 'Product Details'}</h2>
      <button 
        class="close-button" 
        on:click={handleClose}
        aria-label="Close"
      >
        ×
      </button>
    </div>
    <div class="modal-body">
      <div class="product-details">
        <div class="product-image">
          <img 
            src={getProductImage(product.image_url, product.category) + '?width=400&quality=80'} 
            srcset="
              {getProductImage(product.image_url, product.category)}?width=400&quality=80 400w,
              {getProductImage(product.image_url, product.category)}?width=600&quality=80 600w,
              {getProductImage(product.image_url, product.category)}?width=800&quality=80 800w
            "
            sizes="
              (max-width: 800px) 400px,
              (max-width: 1024px) 600px,
              800px
            "
            alt={product.name}
            loading="eager"
            decoding="async"
            width="400"
            height="533"
            style="aspect-ratio: 3/4;"
          />
        </div>
        
        <div class="product-info">
          <div class="product__price-row">
            <span class="product__price">R{product.price}</span>
          </div>
          <div class="quantity-controls-modal">
            <button 
              class="quantity-btn" 
              aria-label="Decrease quantity" 
              on:click={() => handleQuantityChange(-1)}
              disabled={selectedQuantity <= 1 || loading || stock <= 0}
            >-</button>
            <input
              type="number"
              class="quantity-input"
              value={selectedQuantity}
              min="1"
              max={stock}
              on:input={handleQuantityInput}
              on:blur={handleQuantityBlur}
              disabled={loading || stock <= 0}
              aria-label="Product quantity"
            />
            <button 
              class="quantity-btn" 
              aria-label="Increase quantity" 
              on:click={() => handleQuantityChange(1)}
              disabled={selectedQuantity >= stock || loading || stock <= 0}
            >+</button>
            <button 
              class="add-to-cart-btn" 
              on:click={handleAddToCart}
              disabled={loading || stock <= 0}
              aria-label="Add {product.name} to cart"
            >
              {#if loading}
                <span class="loading-spinner" aria-hidden="true"></span>
                <span>Adding...</span>
              {:else if stock <= 0}
                <span>Out of Stock</span>
              {:else}
                Add to Cart
              {/if}
            </button>
          </div>
          {#if product.bulk_prices && product.bulk_prices.length > 0}
            <div class="bulk-pricing">
              <h4>Bulk Pricing</h4>
              <ul>
                {#each [...product.bulk_prices].sort((a, b) => a.min_qty - b.min_qty) as tier}
                  <li>From {tier.min_qty}+: R{tier.price}</li>
                {/each}
              </ul>
            </div>
          {/if}
          
          <p class="product-description">{product.description || 'No description available.'}</p>
          
          {#if product.sativa !== undefined || product.indica !== undefined}
            <div class="strain-type">
              <h3>Strain Type</h3>
              <div class="strain-bar">
                <div 
                  class="strain-indicator" 
                  style="left: {product.indica ?? 0}%"
                  title="{(product.indica ?? 0)}% Indica, {(100 - (product.indica ?? 0))}% Sativa"
                ></div>
              </div>
              <div class="strain-labels">
                <span>Sativa</span>
                <span>Indica</span>
              </div>
            </div>
          {/if}
          
          <div class="potency-info">
            <div class="thc-info">
              <h3>THC Content</h3>
              <div class="potency-bar">
                {#each Array(5) as _, i}
                  <div
                    class="potency-segment"
                    style="background: {i < getPotencyBarCount(product.thc_max) ? thcBarColors[i] : '#eee'}"
                  ></div>
                {/each}
              </div>
              <span class="potency-value">{product.thc_max ?? 0} mg/g</span>
            </div>
            
            <div class="cbd-info">
              <h3>CBD Content</h3>
              <div class="potency-bar">
                {#each Array(5) as _, i}
                  <div
                    class="potency-segment"
                    style="background: {i < getPotencyBarCount(product.cbd_max) ? cbdBarColors[i] : '#eee'}"
                  ></div>
                {/each}
              </div>
              <span class="potency-value">{product.cbd_max ?? 0} mg/g</span>
            </div>
          </div>
          
          <div class="reviews-section">
            <h3>Reviews</h3>
            {#if reviews.length > 0}
              <div class="reviews-list">
                {#each reviews as review}
                  <div class="review-item">
                    <div class="review-header">
                      <div class="review-rating">
                        {#each Array(5) as _, i}
                          <span class="star" class:filled={i < review.rating}>★</span>
                        {/each}
                      </div>
                      <span class="review-user">
                        {review.user?.display_name || review.user?.email?.split('@')[0] || 'Anonymous'}
                      </span>
                    </div>
                    <p class="review-comment">{review.comment}</p>
                    <span class="review-date">{new Date(review.created_at).toLocaleDateString()}</span>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="no-reviews">No reviews yet.</p>
            {/if}
            
            <div class="add-review">
              <h4>{userReview ? 'Update Your Review' : 'Write a Review'}</h4>
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
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.8);
    backdrop-filter: blur(5px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
    animation: fadeIn 0.2s ease;
  }

  .modal-backdrop:focus {
    outline: none;
  }



  .modal-content {
    background: var(--bg-dark-transparent);
    border: 1px solid var(--border-neon);
    border-radius: 16px;
    backdrop-filter: blur(20px);
    box-shadow: var(--shadow-neon), 0 8px 32px rgba(0, 242, 254, 0.2);
    width: 95vw;
    max-width: 500px;
    max-height: 90vh;
    overflow-y: auto;
    animation: slideIn 0.3s ease;
    position: relative;
  }

  .close-button {
    position: absolute;
    top: 12px;
    right: 12px;
    background: rgba(0, 0, 0, 0.7);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: white;
    border-radius: 50%;
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    backdrop-filter: blur(8px);
    z-index: 15;
    transition: all 0.2s ease;
  }

  .close-button:hover {
    background: rgba(255, 69, 69, 0.8);
    border-color: rgba(255, 69, 69, 0.5);
    transform: scale(1.1);
  }

  .product-details {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
    align-items: start;
  }

  .product-image {
    position: sticky;
    top: 2rem;
    display: flex;
    justify-content: center;
    align-items: flex-start;
  }

  .product-image img {
    width: 100%;
    max-width: 400px;
    height: auto;
    border-radius: 8px;
    object-fit: cover;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .product-info {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    padding-right: 1rem;
  }



  .product__price-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin: 0.5rem 0;
  }

  .product__price {
    font-size: 1.5rem;
    font-weight: 600;
    color: #00deff;
    text-shadow: 0 0 8px rgba(0, 222, 255, 0.6);
  }

  .bulk-pricing {
    padding: 1rem;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }

  .bulk-pricing h4 {
    margin: 0 0 0.75rem 0;
    font-size: 1rem;
    color: #b2fefa;
    text-shadow: 0 0 8px rgba(178, 254, 250, 0.5);
  }

  .bulk-pricing ul {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .bulk-pricing li {
    padding: 0.5rem 0;
    color: #ffffff;
    border-bottom: 1px solid rgba(178, 254, 250, 0.1);
  }

  .bulk-pricing li:last-child {
    border-bottom: none;
  }

  .product-description {
    font-size: 1rem;
    line-height: 1.6;
    color: #ffffff;
    margin: 0;
    padding: 1.5rem;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
  }

  .strain-type {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }

  .strain-type h3 {
    margin: 0;
    font-size: 1rem;
    color: #b2fefa;
    text-shadow: 0 0 8px rgba(178, 254, 250, 0.5);
  }

  .strain-bar {
    position: relative;
    height: 6px;
    background: linear-gradient(to right, #fcdd43, #000000);
    border-radius: 3px;
  }

  .strain-indicator {
    position: absolute;
    top: 0;
    width: 2px;
    height: 100%;
    background: white;
    transform: translateX(-50%);
    box-shadow: 0 0 4px rgba(0, 0, 0, 0.3);
  }

  .strain-labels {
    display: flex;
    justify-content: space-between;
    font-size: 0.8rem;
    color: #ffffff;
  }

  .potency-info {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .thc-info,
  .cbd-info {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }

  .thc-info h3,
  .cbd-info h3 {
    margin: 0;
    font-size: 1rem;
    color: #b2fefa;
    text-shadow: 0 0 8px rgba(178, 254, 250, 0.5);
  }

  .potency-bar {
    display: flex;
    gap: 2px;
  }

  .potency-segment {
    flex: 1;
    height: 6px;
    border-radius: 3px;
  }

  .potency-value {
    font-size: 0.8rem;
    color: #ffffff;
    font-weight: 500;
  }

  .reviews-section {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    margin-top: 1rem;
  }

  .reviews-section h3 {
    margin: 0;
    font-size: 1.2rem;
    color: #b2fefa;
    text-shadow: 0 0 8px rgba(178, 254, 250, 0.5);
  }

  .no-reviews {
    color: #ffffff;
    text-align: center;
    padding: 2rem;
    font-style: italic;
    opacity: 0.8;
  }

  .reviews-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .review-item {
    padding: 1rem;
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
    background: rgba(0, 0, 0, 0.3);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }

  .review-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  .review-rating {
    display: flex;
    gap: 0.25rem;
  }

  .star {
    color: #E0E0E0;
    font-size: 1.2rem;
  }

  .star.filled {
    color: #FFD700;
  }

  .review-comment {
    margin: 0 0 0.5rem 0;
    font-size: 0.9rem;
    line-height: 1.5;
    color: #ffffff;
  }

  .review-date {
    font-size: 0.75rem;
    color: #b2fefa;
  }

  .review-user {
    font-size: 0.9rem;
    color: #b2fefa;
    font-weight: 500;
  }

  .add-review {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    padding: 1rem;
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
    background: rgba(0, 0, 0, 0.3);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }

  .add-review h4 {
    margin: 0;
    font-size: 1.1rem;
    color: #b2fefa;
    text-shadow: 0 0 8px rgba(178, 254, 250, 0.5);
  }

  .rating-input {
    display: flex;
    gap: 0.5rem;
  }

  .star-button {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    font-size: 1.5rem;
    color: #555;
    transition: all 0.2s ease;
  }

  .star-button:hover:not(:disabled) {
    transform: scale(1.1);
    color: #FFD700;
  }

  .star-button:disabled {
    cursor: not-allowed;
    opacity: 0.7;
  }

  .star-button .star {
    filter: drop-shadow(0 0 4px rgba(255, 215, 0, 0.3));
    transition: all 0.2s ease;
  }

  .star-button .star.filled {
    filter: drop-shadow(0 0 8px rgba(255, 215, 0, 0.5));
  }

  .add-review textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid rgba(178, 254, 250, 0.3);
    border-radius: 8px;
    resize: vertical;
    min-height: 100px;
    font-family: inherit;
    color: #ffffff;
    background: rgba(0, 0, 0, 0.3);
    transition: all 0.2s ease;
  }

  .add-review textarea:focus {
    outline: none;
    border-color: #00f0ff;
    box-shadow: 
      0 0 0 2px rgba(0, 240, 255, 0.2),
      0 0 10px rgba(0, 240, 255, 0.4);
  }

  .add-review textarea:disabled {
    background: rgba(0, 0, 0, 0.2);
    cursor: not-allowed;
    opacity: 0.7;
  }

  .submit-review {
    background: linear-gradient(77deg, hsl(195.35deg 67.65% 41.89%), #00deff, #14ffbd);
    color: #fff;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    transition: all 0.3s ease;
    text-shadow: 0 0 8px #00f0ff, 0 0 16px #ff00de;
    letter-spacing: 0.5px;
  }

  .submit-review:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 
      0 0 20px rgba(0, 240, 255, 0.4),
      0 0 40px rgba(255, 0, 222, 0.2),
      0 8px 32px rgba(0, 0, 0, 0.3);
  }

  .submit-review:active:not(:disabled) {
    transform: translateY(0);
    box-shadow: 
      0 0 10px rgba(0, 240, 255, 0.3),
      0 0 20px rgba(255, 0, 222, 0.1);
  }

  .submit-review:disabled {
    background: #333;
    color: #666;
    cursor: not-allowed;
    box-shadow: none;
    transform: none;
    text-shadow: none;
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

  @media (max-width: 768px) {
    .modal-content {
      width: 95vw;
      max-width: none;
      margin: 1rem;
    }
    
    .product-name {
      font-size: 1.25rem;
    }
    
    .details-grid {
      grid-template-columns: 1fr;
    }
    
    .cart-section {
      flex-direction: column;
    }
    
    .quantity-input {
      width: 100%;
    }
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slideIn {
    from { 
      opacity: 0; 
      transform: translate(-50%, -50%) scale(0.8); 
    }
    to { 
      opacity: 1; 
      transform: translate(-50%, -50%) scale(1); 
    }
  }

  .modal-content .modal-header {
    position: sticky;
    top: 0;
    background: #1a1a1a;
    z-index: 10;
    padding: 1rem;
    border-bottom: 1px solid rgba(178, 254, 250, 0.3);
  }

  .modal-header h2 {
    color: #b2fefa;
    text-shadow: 0 0 10px rgba(178, 254, 250, 0.5);
  }

  .quantity-controls-modal {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    border: 1px solid rgba(178, 254, 250, 0.2);
    border-radius: 8px;
    background: rgba(0, 0, 0, 0.3);
  }

  .quantity-btn {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    font-size: 1.5rem;
    color: #555;
    transition: all 0.2s ease;
  }

  .quantity-btn:hover:not(:disabled) {
    transform: scale(1.1);
    color: #FFD700;
  }

  .quantity-btn:disabled {
    cursor: not-allowed;
    opacity: 0.7;
  }

  .quantity-input {
    width: 40px;
    padding: 0.25rem;
    border: 1px solid rgba(178, 254, 250, 0.3);
    border-radius: 8px;
    text-align: center;
    font-family: inherit;
    color: #ffffff;
    background: rgba(0, 0, 0, 0.3);
  }

  .add-to-cart-btn {
    background: linear-gradient(77deg, hsl(195.35deg 67.65% 41.89%), #00deff, #14ffbd);
    color: #fff;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    transition: all 0.3s ease;
    text-shadow: 0 0 8px #00f0ff, 0 0 16px #ff00de;
    letter-spacing: 0.5px;
  }

  .add-to-cart-btn:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 
      0 0 20px rgba(0, 240, 255, 0.4),
      0 0 40px rgba(255, 0, 222, 0.2),
      0 8px 32px rgba(0, 0, 0, 0.3);
  }

  .add-to-cart-btn:active:not(:disabled) {
    transform: translateY(0);
    box-shadow: 
      0 0 10px rgba(0, 240, 255, 0.3),
      0 0 20px rgba(255, 0, 222, 0.1);
  }

  .add-to-cart-btn:disabled {
    background: #333;
    color: #666;
    cursor: not-allowed;
    box-shadow: none;
    transform: none;
    text-shadow: none;
  }
</style> 