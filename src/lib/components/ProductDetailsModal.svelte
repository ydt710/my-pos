<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Product } from '$lib/types/index';
  import { getProductReviews, addReview, updateReview, updateProductRating } from '$lib/services/reviewService';
  import { supabase } from '$lib/supabase';
  
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
            src={product.image_url + '?width=400&quality=80'} 
            srcset="
              {product.image_url}?width=400&quality=80 400w,
              {product.image_url}?width=600&quality=80 600w,
              {product.image_url}?width=800&quality=80 800w
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
              <p>No reviews yet.</p>
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
    inset: 0;
    background: rgba(0,0,0,0.4);
    display: flex;
    align-items: flex-start;
    justify-content: center;
     /* navbar height */
    z-index: 3000;
  }

  .modal-backdrop:focus {
    outline: none;
  }

  .modal-backdrop.show {
    opacity: 1;
    visibility: visible;
  }

  .modal-content {
    position: fixed;
   
    transform: translateX(-50%, 0);
    margin-top: 1.5rem;
    max-height: calc(100vh - 90px);
    overflow-y: auto;
    width: 90%;
   
    z-index: 3001;
    background: white;
    border-radius: 12px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
   
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
    z-index: 2002;
    padding: 0.5rem;
    border-radius: 50%;
    transition: background-color 0.2s ease;
  }

  .close-button:hover,
  .close-button:focus {
    background-color: rgba(0, 0, 0, 0.1);
    outline: 2px solid #2196f3;
    outline-offset: 2px;
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

  .product-title {
    font-size: 2rem;
    font-weight: 600;
    margin: 0;
    color: #333;
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
    color: #2196f3;
  }

  .product-description {
    font-size: 1rem;
    line-height: 1.6;
    color: #666;
    margin: 0;
    padding: 1.5rem;
    background: #f8f9fa;
    border-radius: 8px;
  }

  .strain-type {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem;
    background: #f8f9fa;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  }

  .strain-type h3 {
    margin: 0;
    font-size: 1rem;
    color: #333;
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
    color: #666;
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
    background: #f8f9fa;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  }

  .thc-info h3,
  .cbd-info h3 {
    margin: 0;
    font-size: 1rem;
    color: #333;
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
    color: #666;
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
    color: #333;
  }

  .reviews-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .review-item {
    padding: 1rem;
    border: 1px solid #eee;
    border-radius: 8px;
    background: #fff;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
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
    color: #444;
  }

  .review-date {
    font-size: 0.75rem;
    color: #666;
  }

  .review-user {
    font-size: 0.9rem;
    color: #666;
    font-weight: 500;
  }

  .add-review {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    padding: 1rem;
    border: 1px solid #eee;
    border-radius: 8px;
    background: #fff;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  }

  .add-review h4 {
    margin: 0;
    font-size: 1.1rem;
    color: #333;
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
    color: #E0E0E0;
    transition: transform 0.2s ease;
  }

  .star-button:hover:not(:disabled) {
    transform: scale(1.1);
  }

  .star-button:disabled {
    cursor: not-allowed;
    opacity: 0.7;
  }

  .add-review textarea {
    
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    resize: vertical;
    min-height: 100px;
    font-family: inherit;
  }

  .add-review textarea:disabled {
    background: #f5f5f5;
    cursor: not-allowed;
  }

  .submit-review {
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 4px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    transition: all 0.2s ease;
  }

  .submit-review:hover:not(:disabled) {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .submit-review:disabled {
    background: #e0e0e0;
    cursor: not-allowed;
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

  @media (max-width: 800px) {
    .product-details {
      grid-template-columns: 1fr;
    }

    .product-image {
      position: relative;
      top: 0;
    }

    .product-image img {
      max-width: 100%;
    }

    .product-info {
      padding-right: 0;
    }
  }

  @media (max-width: 600px) {
    .modal-content {
      max-width: 98vw;
      margin: 0.5rem;
      margin-top: 1.5rem;
      padding: 0.5rem;
      max-height: calc(100vh - 80px);
    }
  }

  .modal-content .modal-header {
    position: sticky;
    top: 0;
    background: white;
    z-index: 10;
    padding: 1rem;
    border-bottom: 1px solid #ccc;
  }
</style> 