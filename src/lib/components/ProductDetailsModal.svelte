<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import type { Product } from '$lib/types';
  export let product: Product;
  const dispatch = createEventDispatcher();
  function close() { dispatch('close'); }

  // Gradient color arrays for potency bars
  const thcBarColors = ['#4caf50', '#cddc39', '#ffeb3b', '#ff9800', '#f44336'];
  const cbdBarColors = ['#2196f3', '#00bcd4', '#4caf50', '#cddc39', '#ffeb3b'];
  function getPotencyBarCount(min?: number, max?: number): number {
    const value = max ?? min ?? 0;
    if (value > 280) return 5;
    if (value > 210) return 4;
    if (value > 140) return 3;
    if (value > 70) return 2;
    if (value > 0) return 1;
    return 0;
  }
</script>

<div class="modal-backdrop" on:click={close}></div>
<div class="product-modal" in:scale={{ duration: 200 }} out:fade={{ duration: 150 }} on:click|stopPropagation>
  <button class="close-btn" on:click={close} aria-label="Close">×</button>
  <div class="modal-content">
    <div class="modal-image">
      <img src={product.image_url} alt={product.name} />
    </div>
    <div class="modal-details">
      <div class="modal-title">{product.name}</div>
      <div class="modal-price">R{product.price}</div>
      <div class="modal-category">Category: {product.category}</div>
      <div class="modal-description">{product.description}</div>
      <div class="modal-potency">
        <div class="potency-section">
          <h4>THC</h4>
          <div class="potency-bar">
            {#each Array(5) as _, i}
              <div
                class="potency-bar-value"
                style="background: {i < getPotencyBarCount(product.thc_min, product.thc_max) ? thcBarColors[i] : '#eee'}"
              ></div>
            {/each}
          </div>
          <span class="potency-unit">{product.thc_min ?? 0}-{product.thc_max ?? 0} mg/g</span>
        </div>
        <div class="potency-section">
          <h4>CBD</h4>
          <div class="potency-bar">
            {#each Array(5) as _, i}
              <div
                class="potency-bar-value"
                style="background: {i < getPotencyBarCount(product.cbd_min, product.cbd_max) ? cbdBarColors[i] : '#eee'}"
              ></div>
            {/each}
          </div>
          <span class="potency-unit">{product.cbd_min ?? 0}-{product.cbd_max ?? 0} mg/g</span>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.65);
    z-index: 10000;
    animation: fadeIn 0.2s;
  }
  .product-modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: #fff;
    border-radius: 24px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.25);
    z-index: 10001;
    min-width: 340px;
    max-width: 95vw;
    min-height: 320px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    padding: 0;
    overflow: hidden;
    animation: fadeIn 0.2s;
  }
  .close-btn {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: none;
    border: none;
    font-size: 2rem;
    color: #333;
    cursor: pointer;
    z-index: 2;
    transition: color 0.2s;
  }
  .close-btn:hover {
    color: #007bff;
  }
  .modal-content {
    display: flex;
    flex-direction: row;
    align-items: stretch;
    height: 100%;
    width: 100%;
    padding: 2.5rem 2rem 2rem 2rem;
    gap: 2rem;
  }
  .modal-image {
    flex: 1 1 260px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 220px;
    max-width: 320px;
  }
  .modal-image img {
    width: 100%;
    max-width: 320px;
    max-height: 340px;
    border-radius: 20px;
    object-fit: cover;
    box-shadow: 0 4px 16px rgba(0,0,0,0.12);
    background: #f8f8f8;
  }
  .modal-details {
    flex: 2 1 320px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 1.2rem;
    min-width: 200px;
    max-width: 400px;
  }
  .modal-title {
    font-size: 2rem;
    font-weight: 700;
    color: #222;
    margin-bottom: 0.5rem;
  }
  .modal-price {
    font-size: 1.3rem;
    color: #007bff;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }
  .modal-description {
    font-size: 1.1rem;
    color: #444;
    margin-bottom: 0.5rem;
  }
  .modal-category {
    font-size: 1rem;
    color: #888;
  }
  .modal-potency {
    display: flex;
    gap: 2rem;
    margin-top: 1rem;
  }
  .potency-section {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.3rem;
  }
  .potency-bar {
    display: flex;
    gap: 0.15rem;
    margin-bottom: 0.25rem;
  }
  .potency-bar-value {
    width: 22px;
    height: 8px;
    border-radius: 4px;
    background: #eee;
  }
  .potency-unit {
    font-size: 0.9rem;
    color: #555;
  }
  @media (max-width: 700px) {
    .modal-content {
      flex-direction: column;
      padding: 1.5rem 1rem 1rem 1rem;
      gap: 1rem;
    }
    .modal-image {
      min-width: 0;
      max-width: 100%;
      margin-bottom: 1rem;
    }
    .modal-details {
      min-width: 0;
      max-width: 100%;
    }
    .modal-potency {
      flex-direction: column;
      gap: 1rem;
    }
  }
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
</style> 