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

<div class="modal-backdrop" style="z-index:2000;" on:click={handleCancel}></div>
<div class="modal" style="z-index:2001;min-width:350px;max-width:95vw;top:50%;left:50%;transform:translate(-50%,-50%);position:fixed;background:#fff;padding:2rem;border-radius:12px;box-shadow:0 2px 16px rgba(0,0,0,0.2);" role="dialog" aria-modal="true">
  <button class="close-btn" on:click={handleCancel} aria-label="Close edit modal" style="position:absolute;top:1rem;right:1rem;font-size:1.5rem;background:none;border:none;cursor:pointer;">×</button>
  <h3>{isAdd ? 'Add Product' : 'Edit Product'}</h3>
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
    </div>
    <div class="form-actions">
      <button type="submit" class="primary-btn" disabled={loading}>{isAdd ? 'Add' : 'Save'}</button>
      <button type="button" class="secondary-btn" on:click={handleCancel}>Cancel</button>
    </div>
  </form>
  {#if showImageModal}
    <div class="modal-backdrop" style="z-index:2100;" on:click={closeImageModal}></div>
    <div class="modal" style="z-index:2101;min-width:300px;max-width:90vw;top:50%;left:50%;transform:translate(-50%,-50%);position:fixed;background:#fff;padding:1.5rem;border-radius:10px;box-shadow:0 2px 8px rgba(0,0,0,0.15);">
      <h4>Change Product Image</h4>
      <input type="file" accept="image/*" on:change={handleImageChange} />
      <button type="button" class="secondary-btn" on:click={closeImageModal}>Cancel</button>
    </div>
  {/if}
</div>

<style>
  .modal-backdrop {
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0,0,0,0.4);
    z-index: 9998;
  }
  .modal {
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 2px 16px rgba(0,0,0,0.2);
    position: fixed;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    z-index: 9999;
    min-width: 350px;
    max-width: 95vw;
    padding: 2rem;
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
</style> 