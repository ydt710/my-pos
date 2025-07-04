<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { getProductImage } from '$lib/constants';
  export let product: any = {};
  export let categories: { id: string; name: string }[] = [];
  export let loading: boolean = false;
  export let isAdd: boolean = false;

  const dispatch = createEventDispatcher();
  let localProduct: any = {};
  let tempImageUrl = '';
  let showImageModal = false;
  let imageError = '';
  let imageLoading = false;

  onMount(() => {
    localProduct = { ...product };
    tempImageUrl = localProduct.image_url || '';
  });

  // Ensure special_price is tracked
  $: if (!localProduct.is_special) {
    localProduct.special_price = undefined;
  }

  function handleSave() {
    dispatch('save', { product: localProduct });
  }
  function handleCancel() {
    dispatch('cancel');
  }
  function openImageModal() {
    showImageModal = true;
    // Only set tempImageUrl if it's empty, to preserve user input
    if (!tempImageUrl) {
      tempImageUrl = localProduct.image_url || '';
    }
  }
  function closeImageModal() {
    showImageModal = false;
    // Reset tempImageUrl to current product image when closing without saving
    tempImageUrl = localProduct.image_url || '';
  }
  function handleImageChange(event: Event) {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;
    const file = input.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      localProduct.image_url = e.target?.result as string;
    };
    reader.readAsDataURL(file);

    dispatch('imagechange', { file });
    closeImageModal();
  }

  function handleUrlSave() {
    localProduct.image_url = tempImageUrl;
    closeImageModal();
  }

  function handleImageLoad() {
    imageError = '';
    imageLoading = false;
  }

  function handleImageError() {
    imageLoading = false;
    imageError = 'Unable to load image. This may be due to CORS restrictions or an invalid URL.';
  }

  function handleUrlInput() {
    if (tempImageUrl) {
      imageLoading = true;
      imageError = '';
    }
  }
</script>

<div 
  class="modal-backdrop" 
  role="dialog" 
  aria-modal="true" 
  aria-labelledby="product-modal-title"
  on:click={handleCancel}
  on:keydown={(e) => { if (e.key === 'Escape') handleCancel(); }}
>
  <div 
    class="modal-content" 
    role="document"
    on:click|stopPropagation
    on:keydown|stopPropagation
  >
    <div class="modal-header">
      <h2 id="product-modal-title" class="neon-text-cyan">{isAdd ? 'Add New Product' : 'Edit Product'}</h2>
      <button class="modal-close" on:click={handleCancel}>&times;</button>
    </div>

    <form class="modal-body" on:submit|preventDefault={handleSave}>
      <div class="grid grid-2 gap-4">
        <!-- Left Column -->
        <div class="flex flex-col gap-3">
          <div class="form-group">
            <label for="edit-name" class="form-label">Product Name</label>
            <input 
              id="edit-name" 
              bind:value={localProduct.name} 
              placeholder="e.g., Northern Lights" 
              required 
              class="form-control"
            />
          </div>

          <div class="form-group">
            <label for="edit-image" class="form-label">Product Image</label>
            <div class="image-uploader glass" on:click={openImageModal} role="button" tabindex="0">
              {#if localProduct.image_url}
                <img src={localProduct.image_url} alt="Product preview" class="preview-image" />
              {:else}
                <img src={getProductImage(null, localProduct.category || 'flower')} alt="Default category image" class="preview-image default-image" />
                <div class="image-overlay">
                  <span class="neon-text-cyan">Click to upload custom image</span>
                </div>
              {/if}
            </div>
          </div>
          
          <div class="form-group">
            <label for="edit-description" class="form-label">Description</label>
            <textarea 
              id="edit-description" 
              bind:value={localProduct.description} 
              rows="4" 
              placeholder="Briefly describe the product..."
              class="form-control form-textarea"
            ></textarea>
          </div>
        </div>

        <!-- Right Column -->
        <div class="flex flex-col gap-3">
          <div class="grid grid-2 gap-2">
            <div class="form-group">
              <label for="edit-price" class="form-label">Price (R)</label>
              <input 
                id="edit-price" 
                type="number" 
                min="0" 
                step="0.01" 
                bind:value={localProduct.price} 
                placeholder="0.00" 
                required 
                class="form-control"
              />
            </div>
            <div class="form-group">
              <label for="edit-category" class="form-label">Category</label>
              <select id="edit-category" bind:value={localProduct.category} required class="form-control form-select">
                {#each categories as category}
                  <option value={category.id}>{category.name}</option>
                {/each}
              </select>
            </div>
          </div>

          <div class="form-group">
            <label for="edit-indica" class="form-label">Indica / Sativa Blend (%)</label>
            <div class="slider-group">
              <span class="neon-text-cyan">Indica</span>
              <input 
                id="edit-indica" 
                type="range" 
                min="0" 
                max="100" 
                step="1" 
                bind:value={localProduct.indica} 
                class="slider neon-slider"
              />
              <span class="neon-text-cyan">Sativa</span>
            </div>
            <div class="slider-value neon-text-white">
              {localProduct.indica}% / {100 - (localProduct.indica || 0)}%
            </div>
          </div>
          
          <div class="grid grid-2 gap-2">
            <div class="form-group">
              <label for="edit-thc_max" class="form-label">THC Max (mg/g)</label>
              <input 
                id="edit-thc_max" 
                type="number" 
                min="0" 
                step="0.01" 
                bind:value={localProduct.thc_max} 
                placeholder="0.0" 
                class="form-control"
              />
            </div>
            <div class="form-group">
              <label for="edit-cbd_max" class="form-label">CBD Max (mg/g)</label>
              <input 
                id="edit-cbd_max" 
                type="number" 
                min="0" 
                step="0.01" 
                bind:value={localProduct.cbd_max} 
                placeholder="0.0" 
                class="form-control"
              />
            </div>
          </div>

          <div class="checkbox-group">
            <label class="form-checkbox">
              <input type="checkbox" bind:checked={localProduct.is_new} />
              <span class="neon-text-cyan">New Product</span>
            </label>
            <label class="form-checkbox">
              <input type="checkbox" bind:checked={localProduct.is_special} />
              <span class="neon-text-cyan">Special Product</span>
            </label>
            <label class="form-checkbox">
              <input type="checkbox" bind:checked={localProduct.is_out_of_stock} />
              <span class="neon-text-cyan">Out of Stock</span>
            </label>
          </div>

          <div class="stock-management-section glass-light">
            <h4 class="stock-section-title neon-text-cyan">Stock Management</h4>
            <div class="form-group">
              <label for="edit-low-stock-buffer" class="form-label">Low Stock Buffer Amount</label>
              <input 
                id="edit-low-stock-buffer" 
                type="number" 
                min="0" 
                step="1" 
                bind:value={localProduct.low_stock_buffer} 
                placeholder="1000" 
                class="form-control"
              />
              <small class="form-help neon-text-muted">
                Minimum stock level before showing low stock notifications. 
                Set to 0 to disable notifications for this product.
              </small>
            </div>
          </div>
          
          {#if localProduct.is_special}
            <div class="form-group special-price-group glass-light">
              <label for="edit-special-price" class="form-label">Special Price (R)</label>
              <input 
                id="edit-special-price" 
                type="number" 
                min="0" 
                step="0.01" 
                bind:value={localProduct.special_price} 
                placeholder="0.00" 
                required={localProduct.is_special} 
                class="form-control"
              />
            </div>
          {/if}

          <div class="advanced-pricing glass-light">
            <h4 class="advanced-pricing-title neon-text-cyan">Bulk Pricing</h4>
            {#each localProduct.bulk_prices ?? [] as tier, i (i)}
              <div class="bulk-tier-row">
                <input 
                  type="number" 
                  min="1" 
                  step="1" 
                  placeholder="Min Qty" 
                  bind:value={tier.min_qty} 
                  required 
                  class="form-control"
                />
                <input 
                  type="number" 
                  min="0" 
                  step="0.01" 
                  placeholder="Price/item" 
                  bind:value={tier.price} 
                  required 
                  class="form-control"
                />
                <button 
                  type="button" 
                  class="btn btn-danger btn-sm remove-tier-btn" 
                  on:click={() => (localProduct.bulk_prices = (localProduct.bulk_prices ?? []).filter((_: any, j: number) => j !== i))}
                >
                  &times;
                </button>
              </div>
            {/each}
            <button 
              type="button" 
              class="btn btn-secondary btn-sm add-tier-btn" 
              on:click={() => {
                if (!localProduct.bulk_prices) localProduct.bulk_prices = [];
                localProduct.bulk_prices = [...localProduct.bulk_prices, { min_qty: 1, price: 0 }];
              }}
            >
              + Add Tier
            </button>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <div>
          <button 
            type="button" 
            class="btn btn-secondary" 
            on:click={() => dispatch('customprices')}
          >
            Custom Prices
          </button>
        </div>
        <div class="flex gap-2">
          <button type="button" class="btn btn-secondary" on:click={handleCancel}>
            Cancel
          </button>
          <button type="submit" class="btn btn-primary" disabled={loading}>
            {#if loading}
              <div class="spinner"></div>
              <span>Saving...</span>
            {:else}
              {isAdd ? 'Add Product' : 'Save Changes'}
            {/if}
          </button>
        </div>
      </div>
    </form>

    {#if showImageModal}
      <div class="modal-backdrop nested-backdrop" on:click={closeImageModal}></div>
      <div class="image-modal glass" role="dialog" aria-modal="true">
        <div class="modal-header">
          <h4 class="neon-text-cyan">Change Product Image</h4>
          <button class="modal-close" on:click={closeImageModal}>&times;</button>
        </div>
        <div class="modal-body">
          <div class="image-options">
            <!-- URL Input Option -->
            <div class="image-option">
              <h5 class="neon-text-white mb-2">Image URL</h5>
              <p class="neon-text-muted mb-3">Enter a direct link to an image:</p>
              <input 
                type="url" 
                bind:value={tempImageUrl}
                on:input={handleUrlInput}
                placeholder="https://example.com/image.jpg" 
                class="form-control mb-3"
                class:error={imageError}
              />
              
              {#if imageError}
                <div class="error-message">
                  <span class="neon-text-red">{imageError}</span>
                  <p class="error-help neon-text-muted">
                    Try using a direct image link from a service like Imgur, or upload a file instead.
                  </p>
                </div>
              {/if}

              {#if tempImageUrl && !imageError}
                <div class="url-preview">
                  {#if imageLoading}
                    <div class="loading-placeholder">
                      <div class="spinner-small"></div>
                      <span class="neon-text-muted">Loading preview...</span>
                    </div>
                  {:else}
                    <img 
                      src={tempImageUrl} 
                      alt="URL preview" 
                      class="preview-thumbnail" 
                      on:load={handleImageLoad}
                      on:error={handleImageError}
                    />
                  {/if}
                </div>
              {/if}
            </div>

            <div class="divider">
              <span class="neon-text-muted">OR</span>
            </div>

            <!-- File Upload Option -->
            <div class="image-option">
              <h5 class="neon-text-white mb-2">Upload File</h5>
              <p class="neon-text-muted mb-3">Select a new image file to upload:</p>
              <input 
                type="file" 
                accept="image/png, image/jpeg, image/webp" 
                on:change={handleImageChange} 
                class="form-control"
              />
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" on:click={closeImageModal}>
            Cancel
          </button>
          <button type="button" class="btn btn-primary" on:click={handleUrlSave} disabled={!tempImageUrl}>
            Save URL
          </button>
        </div>
      </div>
    {/if}
  </div>
</div>

<style>
  .image-uploader {
    position: relative;
    width: 100%;
    padding-top: 56.25%; /* 16:9 Aspect Ratio */
    cursor: pointer;
    overflow: hidden;
    border: 2px dashed var(--border-primary);
    transition: var(--transition-fast);
  }

  .image-uploader:hover {
    border-color: var(--neon-cyan);
    box-shadow: var(--shadow-neon-cyan);
  }

  .preview-image {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .default-image {
    opacity: 0.7;
  }

  .image-overlay {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    background: rgba(0, 0, 0, 0.8);
    color: var(--neon-cyan);
    text-align: center;
    padding: 0.5rem;
    font-size: 0.9rem;
    transform: translateY(100%);
    transition: transform 0.3s ease;
  }

  .image-uploader:hover .image-overlay {
    transform: translateY(0);
  }

  .image-placeholder {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.9rem;
  }

  .slider-group {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 0.5rem;
  }

  .slider {
    flex-grow: 1;
    height: 8px;
    background: linear-gradient(to right, 
      rgba(255, 0, 222, 0.3) 0%, 
      rgba(0, 240, 255, 0.3) 100%);
    border-radius: 10px;
    outline: none;
    transition: var(--transition-fast);
    position: relative;
    appearance: none;
    border: 1px solid rgba(0, 240, 255, 0.2);
    backdrop-filter: blur(10px);
  }

  .slider:hover {
    box-shadow: 0 0 15px rgba(0, 240, 255, 0.4);
    border-color: var(--neon-cyan);
  }

  .slider:focus {
    box-shadow: 0 0 20px rgba(0, 240, 255, 0.6);
    border-color: var(--neon-cyan);
  }

  .slider::-webkit-slider-thumb {
    appearance: none;
    width: 24px;
    height: 24px;
    background: linear-gradient(135deg, var(--neon-cyan), var(--neon-magenta));
    border-radius: 50%;
    cursor: pointer;
    box-shadow: 
      0 0 15px rgba(0, 240, 255, 0.7),
      0 0 30px rgba(255, 0, 222, 0.3),
      inset 0 0 10px rgba(255, 255, 255, 0.2);
    border: 2px solid rgba(255, 255, 255, 0.3);
    transition: var(--transition-fast);
  }

  .slider::-webkit-slider-thumb:hover {
    transform: scale(1.1);
    box-shadow: 
      0 0 20px rgba(0, 240, 255, 0.9),
      0 0 40px rgba(255, 0, 222, 0.5),
      inset 0 0 15px rgba(255, 255, 255, 0.3);
  }

  .slider::-moz-range-thumb {
    width: 24px;
    height: 24px;
    background: linear-gradient(135deg, var(--neon-cyan), var(--neon-magenta));
    border-radius: 50%;
    cursor: pointer;
    border: 2px solid rgba(255, 255, 255, 0.3);
    box-shadow: 
      0 0 15px rgba(0, 240, 255, 0.7),
      0 0 30px rgba(255, 0, 222, 0.3);
    transition: var(--transition-fast);
  }

  .slider::-moz-range-thumb:hover {
    transform: scale(1.1);
    box-shadow: 
      0 0 20px rgba(0, 240, 255, 0.9),
      0 0 40px rgba(255, 0, 222, 0.5);
  }

  .slider::-moz-range-track {
    height: 8px;
    background: linear-gradient(to right, 
      rgba(255, 0, 222, 0.3) 0%, 
      rgba(0, 240, 255, 0.3) 100%);
    border-radius: 10px;
    border: 1px solid rgba(0, 240, 255, 0.2);
  }

  .slider-value {
    text-align: center;
    font-size: 0.95rem;
    margin-top: 0.75rem;
    font-weight: 600;
    background: linear-gradient(135deg, var(--neon-cyan), var(--neon-magenta));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    text-shadow: 0 0 10px rgba(0, 240, 255, 0.3);
  }

  .checkbox-group {
    display: flex;
    gap: 2rem;
    align-items: center;
    margin: 1rem 0;
  }

  .form-checkbox {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    cursor: pointer;
    transition: var(--transition-fast);
  }

  .form-checkbox:hover {
    transform: translateY(-1px);
  }

  .form-checkbox input[type="checkbox"] {
    width: 1.5rem;
    height: 1.5rem;
    appearance: none;
    background: var(--bg-glass);
    border: 2px solid var(--border-primary);
    border-radius: 6px;
    cursor: pointer;
    position: relative;
    transition: var(--transition-fast);
    backdrop-filter: blur(10px);
  }

  .form-checkbox input[type="checkbox"]:hover {
    border-color: var(--neon-cyan);
    box-shadow: 0 0 10px rgba(0, 240, 255, 0.3);
  }

  .form-checkbox input[type="checkbox"]:checked {
    background: linear-gradient(135deg, var(--neon-cyan), var(--neon-magenta));
    border-color: var(--neon-cyan);
    box-shadow: 
      0 0 15px rgba(0, 240, 255, 0.6),
      0 0 30px rgba(255, 0, 222, 0.3);
  }

  .form-checkbox input[type="checkbox"]:checked::after {
    content: '✓';
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    color: white;
    font-size: 1rem;
    font-weight: bold;
    text-shadow: 0 0 5px rgba(255, 255, 255, 0.8);
  }

  .form-checkbox span {
    font-size: 0.95rem;
    font-weight: 500;
    transition: var(--transition-fast);
  }

  .form-checkbox:hover span {
    color: var(--neon-cyan);
    text-shadow: 0 0 8px rgba(0, 240, 255, 0.4);
  }

  .special-price-group {
    padding: 1rem;
    border-radius: 8px;
    border: 1px solid var(--neon-yellow);
    background: rgba(252, 221, 67, 0.1);
  }

  .stock-management-section {
    padding: 1rem;
    border-radius: 8px;
    margin-top: 1rem;
  }

  .stock-section-title {
    margin: 0 0 1rem 0;
    font-size: 1rem;
    font-weight: 600;
  }

  .form-help {
    display: block;
    margin-top: 0.25rem;
    font-size: 0.8rem;
    line-height: 1.4;
  }

  .advanced-pricing {
    padding: 1rem;
    border-radius: 8px;
    margin-top: 1rem;
  }

  .advanced-pricing-title {
    font-size: 1rem;
    font-weight: 600;
    margin: 0 0 1rem 0;
  }

  .bulk-tier-row {
    display: grid;
    grid-template-columns: 1fr 1fr auto;
    gap: 0.5rem;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  .add-tier-btn {
    margin-top: 0.5rem;
    width: 100%;
  }

  .remove-tier-btn {
    min-width: 32px;
    padding: 0.25rem;
  }

  .nested-backdrop {
    z-index: 3000;
  }

  .image-modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 3001;
    max-width: 500px;
    width: 90%;
  }

  .image-options {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .image-option {
    display: flex;
    flex-direction: column;
  }

  .image-option h5 {
    margin: 0;
    font-size: 1rem;
    font-weight: 600;
  }

  .divider {
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    margin: 0.5rem 0;
  }

  .divider::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 1px;
    background: var(--border-primary);
  }

  .divider span {
    background: var(--bg-secondary);
    padding: 0 1rem;
    font-size: 0.8rem;
    z-index: 1;
    position: relative;
  }

  .url-preview {
    margin-top: 0.5rem;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--border-primary);
  }

  .preview-thumbnail {
    width: 100%;
    height: 120px;
    object-fit: cover;
    display: block;
  }

  .form-control.error {
    border-color: var(--neon-red);
    box-shadow: 0 0 5px rgba(255, 0, 100, 0.3);
  }

  .error-message {
    margin-top: 0.5rem;
    padding: 0.75rem;
    background: rgba(255, 0, 100, 0.1);
    border: 1px solid var(--neon-red);
    border-radius: 6px;
  }

  .error-help {
    margin: 0.5rem 0 0 0;
    font-size: 0.8rem;
    line-height: 1.4;
  }

  .loading-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 120px;
    gap: 0.5rem;
  }

  .spinner-small {
    width: 20px;
    height: 20px;
    border: 2px solid var(--bg-tertiary);
    border-top: 2px solid var(--neon-cyan);
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  @media (max-width: 820px) {
    .grid-2 {
      grid-template-columns: 1fr;
    }
    
    .modal-content {
      width: 95vw;
      max-height: 95vh;
      margin: 0.5rem;
    }
    
    .checkbox-group {
      flex-direction: column;
      align-items: flex-start;
      gap: 1rem;
    }
  }
</style>