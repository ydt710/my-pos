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
    localProduct.image_url = URL.createObjectURL(file);
    closeImageModal();
  }
</script>

<div class="modal-backdrop" style="z-index:2000;" role="button" tabindex="0" on:click={handleCancel} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleCancel(); }}></div>
<div class="modal" style="z-index:3001;min-width:320px;max-width:95vw;top:50%;left:50%;transform:translate(-50%,-50%);position:fixed;background:#fff;padding:2rem;border-radius:12px;box-shadow:0 2px 16px rgba(0,0,0,0.2);max-height:90vh;overflow-y:auto;" role="dialog" aria-modal="true" aria-labelledby="modal-title">
  
  <div class="modal-content" role="document">
    <div class="modal-header">
      <h2 id="modal-title" tabindex="-1">{isAdd ? 'Add Product' : 'Edit Product'}</h2>
      <button class="close-btn" on:click={handleCancel} aria-label="Close">×</button>
    </div>
    <form on:submit|preventDefault={handleSave}>
      <div class="form-grid">
        <div class="form-group">
          <label for="edit-name">Name</label>
          <input id="edit-name" bind:value={localProduct.name} placeholder="Product name" required />
        </div>
        <div class="form-group">
          <label for="edit-price">Price</label>
          <input id="edit-price" type="number" min="0" step="0.01" bind:value={localProduct.price} placeholder="Price" required />
        </div>
        <div class="form-group">
          <label for="edit-image">Product Image</label>
          <div class="image-input-container">
            {#if localProduct.image_url}
              <div class="image-preview">
                <img src={localProduct.image_url} alt="Product preview" class="preview-image" />
              </div>
            {/if}
            <button type="button" class="image-btn" on:click={openImageModal}>
              Change Image
            </button>
          </div>
        </div>
        <div class="form-group">
          <label for="edit-category">Category</label>
          <select id="edit-category" bind:value={localProduct.category} required>
            {#each categories as category}
              <option value={category.id}>{category.name}</option>
            {/each}
          </select>
        </div>
        <div class="form-group">
          <label for="edit-thc_max">THC Max (mg/g)</label>
          <input id="edit-thc_max" type="number" min="0" step="0.01" bind:value={localProduct.thc_max} placeholder="THC max (mg/g)" required />
        </div>
        <div class="form-group">
          <label for="edit-cbd_max">CBD Max (mg/g)</label>
          <input id="edit-cbd_max" type="number" min="0" step="0.01" bind:value={localProduct.cbd_max} placeholder="CBD max (mg/g)" required />
        </div>
        <div class="form-group">
          <label for="edit-indica">Indica (%)</label>
          <input id="edit-indica" type="number" min="0" max="100" step="1" bind:value={localProduct.indica} placeholder="Indica % (0-100)" required />
        </div>
        <div class="form-group">
          <label for="edit-description">Description</label>
          <textarea id="edit-description" bind:value={localProduct.description} rows="2" placeholder="Product description..."></textarea>
        </div>
        <div class="form-group">
          <label><input type="checkbox" bind:checked={localProduct.is_new}> New Product</label>
        </div>
        <div class="form-group">
          <label><input type="checkbox" bind:checked={localProduct.is_special}> Special</label>
        </div>
        {#if localProduct.is_special}
          <div class="form-group">
            <label for="edit-special-price">Special Price</label>
            <input id="edit-special-price" type="number" min="0" step="0.01" bind:value={localProduct.special_price} placeholder="Special price" required={localProduct.is_special} />
          </div>
        {/if}
        <div class="form-group">
          <label for="bulk-tier-min-0">Bulk Pricing (Price Tiers)</label>
          <div>
            {#each localProduct.bulk_prices ?? [] as tier, i (i)}
              <div style="display:flex;align-items:center;gap:0.5rem;margin-bottom:0.5rem;">
                <input id={`bulk-tier-min-${i}`} type="number" min="1" step="1" placeholder="Min Qty" bind:value={tier.min_qty} style="width:80px;" required />
                <input type="number" min="0" step="0.01" placeholder="Price" bind:value={tier.price} style="width:100px;" required />
                <button type="button" class="secondary-btn" on:click={() => (localProduct.bulk_prices = (localProduct.bulk_prices ?? []).filter((_: number, j: number) => j !== i))}>Remove</button>
              </div>
            {/each}
            <button type="button" class="secondary-btn" on:click={() => {
              if (!localProduct.bulk_prices) localProduct.bulk_prices = [];
              localProduct.bulk_prices = [...localProduct.bulk_prices, { min_qty: 1, price: 0 }];
            }}>Add Tier</button>
          </div>
        </div>
      </div>
      <div class="form-actions">
        <button type="submit" class="primary-btn" disabled={loading}>{isAdd ? 'Add' : 'Save'}</button>
        <button type="button" class="secondary-btn" on:click={handleCancel}>Cancel</button>
      </div>
      <button type="button" class="secondary-btn" style="margin-top:1rem;" on:click={() => dispatch('customprices')}>
        Custom Prices
      </button>
    </form>
    {#if showImageModal}
      <div class="modal-backdrop" style="z-index:2100;" role="button" tabindex="0" on:click={closeImageModal} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') closeImageModal(); }}></div>
      <div class="modal" style="z-index:2101;min-width:300px;max-width:90vw;top:50%;left:50%;transform:translate(-50%,-50%);position:fixed;background:#fff;padding:1.5rem;border-radius:10px;box-shadow:0 2px 8px rgba(0,0,0,0.15);">
        <h4>Change Product Image</h4>
        <input type="file" accept="image/*" on:change={handleImageChange} />
        <button type="button" class="secondary-btn" on:click={closeImageModal}>Cancel</button>
      </div>
    {/if}
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
    padding-top: 70px; /* navbar height */
    z-index: 3000;
  }
  .modal {
    position: fixed;
    left: 50%;
    transform: translateX(-50%, 0);
    margin-top: 1.5rem;
    max-height: calc(100vh - 90px);
    overflow-y: auto;
   
 
    z-index: 3001;
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 2px 16px rgba(0,0,0,0.2);
    
  }
  @media (max-width: 600px) {
    .modal {
      max-width: 98vw;
      margin: 0.5rem;
      margin-top: 1.5rem;
      padding: 0.5rem;
      max-height: calc(100vh - 80px);
    }
  }
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    position: absolute;
    top: 1rem;
    right: 1rem;
  }
  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    margin-bottom: 1.5rem;
  }
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .image-preview img {
    max-width: 80px;
    max-height: 80px;
    width: auto;
    height: auto;
    object-fit: contain;
    border-radius: 4px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.08);
  }
  .form-actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
  }
  .primary-btn {
    background: #007bff;
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.75rem 1.5rem;
    font-size: 1rem;
    cursor: pointer;
  }
  .secondary-btn {
    background: #6c757d;
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.75rem 1.5rem;
    font-size: 1rem;
    cursor: pointer;
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