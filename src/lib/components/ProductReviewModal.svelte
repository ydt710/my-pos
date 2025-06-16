<script lang="ts">
  import type { Product } from '$lib/types/index';
  export let userReview: any = null;
  export let newReview: { rating: number; comment: string };
  export let submittingReview: boolean = false;
  export let show: boolean = false;
  export let onSubmit: () => void;
  export let onClose: () => void;
  export let setRating: (rating: number) => void;
  export let setComment: (comment: string) => void;
 
</script>

{#if show}
  <div class="review-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
    <div class="review-modal__content" role="document">
      <div class="modal-header">
        <h2 id="modal-title" tabindex="-1">{userReview ? 'Update Your Review' : 'Write a Review'}</h2>
        <button class="close-button" on:click={onClose} aria-label="Close">×</button>
      </div>
      <div class="modal-body">
        <div class="rating-input">
          {#each Array(5) as _, i}
            <button 
              class="star-button" 
              on:click={() => setRating(i + 1)}
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
          on:input={(e: Event) => setComment(((e.target as HTMLTextAreaElement)?.value) || '')}
        ></textarea>
        <button 
          class="submit-review" 
          on:click={onSubmit}
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
{/if}

<style>
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
    z-index: 2000;
  }
  .review-modal__content {
    position: relative;
    background: white;
    padding: 2rem;
    border-radius: 12px;
    width: 90%;
    
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
  .modal-header {
    position: sticky;
    top: 0;
    background: white;
    z-index: 10;
    padding: 1rem;
    border-bottom: 1px solid #ccc;
  }
</style> 