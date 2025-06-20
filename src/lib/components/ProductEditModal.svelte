<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  export let product: any = {};
  export let categories: { id: string; name: string }[] = [];
  export let loading: boolean = false;
  export let isAdd: boolean = false;

  const dispatch = createEventDispatcher();
  let localProduct: any = {};
  let tempImageUrl = '';
  let showImageModal = false;

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
    tempImageUrl = localProduct.image_url || '';
  }
  function closeImageModal() {
    showImageModal = false;
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
</script>

<div class="modal-backdrop" on:click={handleCancel}></div>
<div class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <div class="modal-content">
    <div class="modal-header">
      <h2 id="modal-title">{isAdd ? 'Add New Product' : 'Edit Product'}</h2>
      <button class="close-btn" on:click={handleCancel}>&times;</button>
    </div>

    <form class="modal-body" on:submit|preventDefault={handleSave}>
      <div class="form-grid">
        <!-- Left Column -->
        <div class="form-column">
          <div class="form-group">
            <label for="edit-name">Product Name</label>
            <input id="edit-name" bind:value={localProduct.name} placeholder="e.g., Northern Lights" required />
          </div>

          <div class="form-group">
            <label for="edit-image">Product Image</label>
            <div class="image-uploader" on:click={openImageModal} role="button" tabindex="0">
              {#if localProduct.image_url}
                <img src={localProduct.image_url} alt="Product preview" class="preview-image" />
              {:else}
                <div class="image-placeholder">
                  <span>Click to upload</span>
                </div>
              {/if}
            </div>
          </div>
          
          <div class="form-group">
            <label for="edit-description">Description</label>
            <textarea id="edit-description" bind:value={localProduct.description} rows="4" placeholder="Briefly describe the product..."></textarea>
          </div>
        </div>

        <!-- Right Column -->
        <div class="form-column">
          <div class="form-row">
            <div class="form-group">
              <label for="edit-price">Price (R)</label>
              <input id="edit-price" type="number" min="0" step="0.01" bind:value={localProduct.price} placeholder="0.00" required />
            </div>
            <div class="form-group">
              <label for="edit-category">Category</label>
              <select id="edit-category" bind:value={localProduct.category} required>
                {#each categories as category}
                  <option value={category.id}>{category.name}</option>
                {/each}
              </select>
            </div>
          </div>

          <div class="form-group">
            <label for="edit-indica">Indica / Sativa Blend (%)</label>
            <div class="slider-group">
              <span>Indica</span>
              <input id="edit-indica" type="range" min="0" max="100" step="1" bind:value={localProduct.indica} />
              <span>Sativa</span>
            </div>
            <div class="slider-value">{localProduct.indica}% / {100 - (localProduct.indica || 0)}%</div>
          </div>
          
          <div class="form-row">
            <div class="form-group">
              <label for="edit-thc_max">THC Max (mg/g)</label>
              <input id="edit-thc_max" type="number" min="0" step="0.01" bind:value={localProduct.thc_max} placeholder="0.0" />
            </div>
            <div class="form-group">
              <label for="edit-cbd_max">CBD Max (mg/g)</label>
              <input id="edit-cbd_max" type="number" min="0" step="0.01" bind:value={localProduct.cbd_max} placeholder="0.0" />
            </div>
          </div>

          <div class="form-group checkbox-group">
            <label class="checkbox-label">
              <input type="checkbox" bind:checked={localProduct.is_new} />
              New Product
            </label>
            <label class="checkbox-label">
              <input type="checkbox" bind:checked={localProduct.is_special} />
              On Special
            </label>
          </div>
          
          {#if localProduct.is_special}
            <div class="form-group special-price-group">
              <label for="edit-special-price">Special Price (R)</label>
              <input id="edit-special-price" type="number" min="0" step="0.01" bind:value={localProduct.special_price} placeholder="0.00" required={localProduct.is_special} />
            </div>
          {/if}

          <div class="advanced-pricing">
            <h4 class="advanced-pricing-title">Bulk Pricing</h4>
            {#each localProduct.bulk_prices ?? [] as tier, i (i)}
              <div class="bulk-tier-row">
                <input type="number" min="1" step="1" placeholder="Min Qty" bind:value={tier.min_qty} required />
                <input type="number" min="0" step="0.01" placeholder="Price/item" bind:value={tier.price} required />
                <button type="button" class="remove-tier-btn" on:click={() => (localProduct.bulk_prices = (localProduct.bulk_prices ?? []).filter((_: any, j: number) => j !== i))}>&times;</button>
              </div>
            {/each}
            <button type="button" class="add-tier-btn" on:click={() => {
              if (!localProduct.bulk_prices) localProduct.bulk_prices = [];
              localProduct.bulk_prices = [...localProduct.bulk_prices, { min_qty: 1, price: 0 }];
            }}>+ Add Tier</button>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <div>
          <button type="button" class="secondary-btn" on:click={() => dispatch('customprices')}>Custom Prices</button>
        </div>
        <div>
          <button type="button" class="secondary-btn" on:click={handleCancel}>Cancel</button>
          <button type="submit" class="primary-btn" disabled={loading}>
            {#if loading}
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
      <div class="modal image-modal" role="dialog" aria-modal="true">
        <h4>Change Product Image</h4>
        <p>Select a new image file to upload.</p>
        <input type="file" accept="image/png, image/jpeg, image/webp" on:change={handleImageChange} />
        <button type="button" class="secondary-btn" on:click={closeImageModal}>Cancel</button>
      </div>
    {/if}
  </div>
</div>

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    z-index: 2000;
  }

  .modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 2001;
    display: flex;
    flex-direction: column;
    width: auto;
    min-width: 320px;
    max-width: 800px;
    max-height: 90vh;
    background: #f8f9fa;
    border-radius: 16px;
    box-shadow: 0 5px 20px rgba(0,0,0,0.2);
  }

  .modal-content {
    display: flex;
    flex-direction: column;
    overflow: hidden;
    height: 100%;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e9ecef;
    background: white;
    flex-shrink: 0;
  }

  .modal-header h2 {
    margin: 0;
    font-size: 1.25rem;
    color: #343a40;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 2rem;
    line-height: 1;
    color: #6c757d;
    cursor: pointer;
    padding: 0;
    transition: color 0.2s;
  }
  .close-btn:hover {
    color: #343a40;
  }

  .modal-body {
    overflow-y: auto;
    padding: 1.5rem;
    flex-grow: 1;
  }

  .form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
  }

  .form-column {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.25rem;
  }

  .form-group {
    display: flex;
    flex-direction: column;
  }
  
  .form-group label, .checkbox-label {
    margin-bottom: 0.5rem;
    font-size: 0.9rem;
    font-weight: 500;
    color: #495057;
  }

  input[type="text"],
  input[type="number"],
  select,
  textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ced4da;
    border-radius: 8px;
    font-size: 1rem;
    background: white;
    transition: border-color 0.2s, box-shadow 0.2s;
  }

  input:focus, select:focus, textarea:focus {
    outline: none;
    border-color: #80bdff;
    box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.15);
  }
  
  textarea {
    resize: vertical;
    min-height: 80px;
  }
  
  .image-uploader {
    position: relative;
    width: 100%;
    padding-top: 56.25%; /* 16:9 Aspect Ratio */
    background: #e9ecef;
    border-radius: 8px;
    cursor: pointer;
    overflow: hidden;
    border: 2px dashed #ced4da;
    transition: border-color 0.2s;
  }
  .image-uploader:hover {
    border-color: #007bff;
  }
  .image-uploader .preview-image {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
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
    color: #6c757d;
    font-size: 0.9rem;
  }

  .slider-group {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  input[type="range"] {
    flex-grow: 1;
    padding: 0;
  }
  .slider-value {
    text-align: center;
    font-size: 0.9rem;
    color: #6c757d;
    margin-top: 0.25rem;
  }

  .checkbox-group {
    flex-direction: row;
    gap: 2rem;
    align-items: center;
  }
  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
    font-weight: normal;
  }
  input[type="checkbox"] {
    width: 1.25rem;
    height: 1.25rem;
  }
  
  .special-price-group {
    background: #fffbe6;
    padding: 1rem;
    border-radius: 8px;
    border: 1px solid #ffeeba;
  }

  .advanced-pricing {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #e9ecef;
  }
  .advanced-pricing-title {
    font-size: 1rem;
    font-weight: 500;
    color: #495057;
    margin-bottom: 0.75rem;
  }
  .bulk-tier-row {
    display: grid;
    grid-template-columns: 1fr 1fr auto;
    gap: 0.5rem;
    align-items: center;
    margin-bottom: 0.5rem;
  }
  .remove-tier-btn, .add-tier-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 1.2rem;
    color: #6c757d;
    transition: color 0.2s;
  }
  .remove-tier-btn:hover { color: #dc3545; }
  .add-tier-btn {
    background: #e9ecef;
    color: #495057;
    border-radius: 6px;
    padding: 0.25rem 0.5rem;
    font-size: 0.9rem;
    margin-top: 0.5rem;
  }
  .add-tier-btn:hover { background: #dee2e6; }

  .modal-footer {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    padding: 1rem 1.5rem;
    border-top: 1px solid #e9ecef;
    background: white;
    flex-shrink: 0;
  }

  .primary-btn, .secondary-btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .primary-btn {
    background: linear-gradient(to right, #0062E6, #33AEFF);
    color: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }
  .primary-btn:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 2px 6px rgba(0,0,0,0.15);
  }
  .primary-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .secondary-btn {
    background: #e9ecef;
    color: #343a40;
    border: 1px solid #ced4da;
  }
  .secondary-btn:hover {
    background: #dee2e6;
  }

  .nested-backdrop {
    z-index: 3000;
  }
  .image-modal {
    z-index: 3001;
    padding: 1.5rem;
    background: white;
  }
  .image-modal h4 {
    margin-top: 0;
  }
  
  @media (max-width: 820px) {
    .form-grid {
      grid-template-columns: 1fr;
    }
    .modal {
        width: 95vw;
        max-height: 95vh;
    }
  }
</style>