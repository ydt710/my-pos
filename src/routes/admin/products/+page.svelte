<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import type { Product } from '$lib/types/index';
  import { showSnackbar } from '$lib/stores/snackbarStore';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import ProductEditModal from '$lib/components/ProductEditModal.svelte';
  import { getShopStockLevels } from '$lib/services/stockService';
  import { PUBLIC_SHOP_LOCATION_ID } from '$env/static/public';

  let products: Product[] = [];
  let filteredProducts: Product[] = [];
  let loading = true;
  let error = '';
  let editing: Partial<Product> | null = null;
  let newProduct: Partial<Product> = { 
    name: '', 
    description: '',
    price: 0, 
    image_url: '', 
    category: 'flower', // Default category
    thc_max: 0,
    cbd_max: 0,
    indica: 0,
    is_new: false,
    is_special: false
  };
  let imageFile: File | null = null;
  let uploadProgress = 0;
  let isUploading = false;
  
  let showProductConfirmModal = false;
  let productIdToDelete: string | null = null;
  
  const categories = [
    { id: 'joints', name: 'Joints' },
    { id: 'concentrate', name: 'Concentrate' },
    { id: 'flower', name: 'Flower' },
    { id: 'edibles', name: 'Edibles' },
    { id: 'headshop', name: 'Headshop' }
  ];

  let productFilters = {
    search: '',
    category: '',
    minPrice: '',
    maxPrice: '',
    sortBy: 'name',
    sortOrder: 'asc'
  };

  let showCustomPrices = false;
  let customPrices: { id: string, user_id: string, product_id: string, custom_price: number, email?: string, display_name?: string }[] = [];
  let customPriceUserSearch = '';
  let customPriceUserResults: { id: string, email: string, display_name: string }[] = [];
  let newCustomPrice = '';
  let selectedCustomPriceUser: { id: string, email: string, display_name: string } | null = null;
  let customPriceError = '';
  let customPriceUserLoading = false;

  let showEditModal = false;
  let isAddMode = false;

  let stockLevels: { [productId: string]: number } = {};

  onMount(() => {
    fetchProducts();
  });

  async function fetchProducts() {
    loading = true;
    const { data, error: err } = await supabase.from('products').select('*');
    loading = false;
    if (err) error = err.message;
    else {
      products = (data ?? []).map(p => ({ ...p, id: String(p.id) })) as Product[];
      stockLevels = await getShopStockLevels(products.map(p => p.id));
      applyProductFilters();
    }
  }

  function applyProductFilters() {
    filteredProducts = products.filter(product => {
      if (productFilters.search && !product.name.toLowerCase().includes(productFilters.search.toLowerCase())) {
        return false;
      }
      if (productFilters.category && product.category !== productFilters.category) {
        return false;
      }
      if (productFilters.minPrice && product.price < Number(productFilters.minPrice)) {
        return false;
      }
      if (productFilters.maxPrice && product.price > Number(productFilters.maxPrice)) {
        return false;
      }
      return true;
    });

    filteredProducts.sort((a, b) => {
      let comparison = 0;
      switch (productFilters.sortBy) {
        case 'name':
          comparison = a.name.localeCompare(b.name);
          break;
        case 'price':
          comparison = a.price - b.price;
          break;
        case 'category':
          comparison = a.category.localeCompare(b.category);
          break;
        default:
          comparison = 0;
      }
      return productFilters.sortOrder === 'asc' ? comparison : -comparison;
    });
  }

  $: if (products.length > 0) {
    applyProductFilters();
  }

  async function uploadImageToStorage(file: File): Promise<string> {
    isUploading = true;
    uploadProgress = 0;
    try {
        const fileExt = file.name.split('.').pop();
        const fileName = `${Date.now()}.${fileExt}`;
        const filePath = `product-images/${fileName}`;
        const { data, error: uploadError } = await supabase.storage
            .from('products')
            .upload(filePath, file, { cacheControl: '3600', upsert: false });
        if (uploadError) throw uploadError;
        const { data: { publicUrl } } = supabase.storage
            .from('products')
            .getPublicUrl(filePath);
        uploadProgress = 100;
        return publicUrl;
    } catch (err) {
        console.error('Error uploading image:', err);
        throw err;
    } finally {
        isUploading = false;
    }
  }

  async function saveProduct() {
    loading = true;
    error = '';
    try {
        let imageUrl = editing ? editing.image_url : newProduct.image_url;
        if (imageFile) {
            imageUrl = await uploadImageToStorage(imageFile);
        }
        
        const productData = isAddMode ? { ...newProduct, image_url: imageUrl } : { ...editing, image_url: imageUrl };
        
        if (!isAddMode && editing?.id) {
            const { error: err } = await supabase.from('products').update(productData).eq('id', editing.id);
            if (err) error = err.message;
        } else {
            const { data, error: err } = await supabase.from('products').insert([productData]).select().single();
            if (err) {
              error = err.message;
            } else if (data) {
              const shopLocationId = PUBLIC_SHOP_LOCATION_ID;
              await supabase.from('stock_levels').insert([{ product_id: data.id, location_id: shopLocationId, quantity: 0 }]);
            }
        }
        imageFile = null;
        uploadProgress = 0;
        closeEditModal();
        await fetchProducts();
        showSnackbar(`Product ${isAddMode ? 'added' : 'updated'} successfully.`);
    } catch (err) {
        console.error('Error saving product:', err);
        error = 'An unexpected error occurred';
    } finally {
        loading = false;
    }
  }

  function openEditModal(product: Product) {
    editing = { ...product };
    showEditModal = true;
    isAddMode = false;
  }
  
  function openAddModal() {
    editing = { ...newProduct };
    showEditModal = true;
    isAddMode = true;
  }

  function closeEditModal() {
    editing = null;
    showEditModal = false;
    isAddMode = false;
  }

  async function deleteProduct(id: string) {
    loading = true;
    error = '';
    try {
      const { error: err } = await supabase.from('products').delete().eq('id', id);
      if (err) throw err;
      products = products.filter(p => String(p.id) !== String(id));
      showSnackbar('Product deleted successfully.');
      await fetchProducts();
    } catch (err) {
      console.error('Error deleting product:', err);
      error = 'Failed to delete product. Please try again.';
      showSnackbar(error);
    } finally {
      loading = false;
    }
  }

  async function fetchCustomPricesForProduct(productId: string) {
    if (!productId) { customPrices = []; return; }
    const { data, error } = await supabase
      .from('user_product_prices')
      .select('id, user_id, product_id, custom_price, profiles: user_id (email, display_name)')
      .eq('product_id', productId);
    if (error) { customPrices = []; return; }
    customPrices = (data || []).map(row => {
      let profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
      return {
        id: row.id,
        user_id: row.user_id,
        product_id: row.product_id,
        custom_price: row.custom_price,
        email: profile?.email,
        display_name: profile?.display_name
      };
    });
  }

  async function searchCustomPriceUsers() {
    if (customPriceUserSearch.length < 2) {
      customPriceUserResults = [];
      return;
    }
    customPriceUserLoading = true;
    const { data, error } = await supabase
      .from('profiles')
      .select('id, email, display_name')
      .or(`display_name.ilike.%${customPriceUserSearch}%,email.ilike.%${customPriceUserSearch}%`)
      .limit(10);
    customPriceUserResults = data || [];
    customPriceUserLoading = false;
  }

  function selectCustomPriceUser(user: { id: string, email: string, display_name: string }) {
    selectedCustomPriceUser = user;
    customPriceUserResults = [];
    customPriceUserSearch = user.display_name || user.email;
  }

  async function addCustomPrice() {
    customPriceError = '';
    if (!selectedCustomPriceUser || !editing || !newCustomPrice) {
      customPriceError = 'Select a user and enter a price.';
      return;
    }
    const { error } = await supabase
      .from('user_product_prices')
      .upsert([
        { user_id: selectedCustomPriceUser.id, product_id: String(editing.id), custom_price: Number(newCustomPrice) }
      ], { onConflict: 'user_id,product_id' });
    if (error) {
      customPriceError = error.message;
      return;
    }
    await fetchCustomPricesForProduct(String(editing.id));
    selectedCustomPriceUser = null;
    customPriceUserSearch = '';
    newCustomPrice = '';
  }

  async function removeCustomPrice(id: string) {
    await supabase.from('user_product_prices').delete().eq('id', id);
    if (editing) await fetchCustomPricesForProduct(String(editing.id));
  }

  $: if (editing && showCustomPrices) {
    fetchCustomPricesForProduct(String(editing.id));
  }

</script>

<div class="product-management-page">
  <div class="section-header">
      <h2>Product Management</h2>
      <button class="primary-btn" on:click={openAddModal}>+ Add Product</button>
  </div>

  <div class="filters-card">
    <div class="filters-grid">
      <div class="filter-group"><label for="search">Search</label><input id="search" type="text" placeholder="Search products..." bind:value={productFilters.search} on:input={applyProductFilters}/></div>
      <div class="filter-group"><label for="category">Category</label><select id="category" bind:value={productFilters.category} on:change={applyProductFilters}><option value="">All Categories</option>{#each categories as category}<option value={category.id}>{category.name}</option>{/each}</select></div>
      <div class="filter-group"><label for="minPrice">Min Price</label><input id="minPrice" type="number" min="0" step="0.01" placeholder="Min price" bind:value={productFilters.minPrice} on:input={applyProductFilters}/></div>
      <div class="filter-group"><label for="maxPrice">Max Price</label><input id="maxPrice" type="number" min="0" step="0.01" placeholder="Max price" bind:value={productFilters.maxPrice} on:input={applyProductFilters}/></div>
      <div class="filter-group"><label for="sortBy">Sort By</label><select id="sortBy" bind:value={productFilters.sortBy} on:change={applyProductFilters}><option value="name">Name</option><option value="price">Price</option><option value="category">Category</option></select></div>
      <div class="filter-group"><label for="sortOrder">Order</label><select id="sortOrder" bind:value={productFilters.sortOrder} on:change={applyProductFilters}><option value="asc">Ascending</option><option value="desc">Descending</option></select></div>
    </div>
  </div>
  
  {#if showEditModal && editing}
    <ProductEditModal
      product={editing}
      categories={categories}
      loading={loading}
      isAdd={isAddMode}
      on:save={async (e) => { 
        if(isAddMode) {
          newProduct = e.detail.product;
        } else {
          editing = e.detail.product;
        }
        await saveProduct(); 
      }}
      on:cancel={closeEditModal}
      on:customprices={() => showCustomPrices = true}
    />
  {/if}
  
  <div class="table-card">
    <div class="table-responsive">
      <table>
        <thead>
          <tr>
            <th>Image</th><th>Name</th><th>Category</th><th>Price</th><th>Tags</th><th>Stock</th><th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredProducts as product (product.id)}
            <tr>
              <td><img src={product.image_url} alt={product.name} class="product-thumbnail"/></td>
              <td>{product.name}</td>
              <td>{categories.find(c => String(c.id) === String(product.category))?.name || product.category}</td>
              <td>
                {#if product.is_special && product.special_price}
                  <span style="text-decoration: line-through; color: #888;">R{product.price}</span>
                  <span style="color: #e67e22; font-weight: bold; margin-left: 0.5em;">R{product.special_price}</span>
                {:else}
                  R{product.price}
                {/if}
              </td>
              <td>
                {#if product.is_new}<span class="tag-badge new">New</span>{/if}
                {#if product.is_special}<span class="tag-badge special">Special</span>{/if}
              </td>
              <td>{stockLevels[product.id] ?? 0}</td>
              <td class="action-buttons">
                <button class="edit-btn" on:click={() => openEditModal(product)}>Edit</button>
                <button class="delete-btn" on:click={() => { showProductConfirmModal = true; productIdToDelete = String(product.id); }}>Delete</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </div>

  {#if showProductConfirmModal}
      <ConfirmModal
          message="Are you sure you want to delete this product?"
          onConfirm={() => { if (productIdToDelete !== null) deleteProduct(productIdToDelete); showProductConfirmModal = false; productIdToDelete = null; }}
          onCancel={() => { showProductConfirmModal = false; productIdToDelete = null; }}
      />
  {/if}

  {#if editing && showCustomPrices}
      <div class="modal-backdrop" role="button" on:click={() => showCustomPrices = false}></div>
      <div class="modal custom-prices-modal" role="dialog" aria-modal="true">
        <div class="modal-header">
          <h3>Custom Prices for {editing.name}</h3>
          <button class="close-btn" on:click={() => showCustomPrices = false}>&times;</button>
        </div>
        <div class="modal-body">
          <div class="add-custom-price-form">
            <div class="form-group">
              <label for="user-search">Search for a user</label>
              <div class="search-wrapper">
                <input id="user-search" type="text" placeholder="Search by name or email..." bind:value={customPriceUserSearch} on:input={searchCustomPriceUsers} />
                {#if customPriceUserLoading}<div class="spinner"></div>{/if}
              </div>
              {#if customPriceUserResults.length > 0}
                <ul class="user-search-results">
                  {#each customPriceUserResults as user}
                    <li on:click={() => selectCustomPriceUser(user)} on:keydown={(e) => e.key === 'Enter' && selectCustomPriceUser(user)} tabindex="0" role="button">
                      {user.display_name || user.email}
                    </li>
                  {/each}
                </ul>
              {/if}
            </div>

            {#if selectedCustomPriceUser}
              <div class="selected-user-info">
                Selected: <strong>{selectedCustomPriceUser.display_name || selectedCustomPriceUser.email}</strong>
              </div>
            {/if}
            
            <div class="form-group">
              <label for="new-custom-price">Set Custom Price (R)</label>
              <div class="price-input-group">
                <input id="new-custom-price" type="number" min="0" step="0.01" placeholder="Enter price" bind:value={newCustomPrice} />
                <button class="primary-btn" on:click={addCustomPrice}>Add Price</button>
              </div>
            </div>
            {#if customPriceError}<p class="error-message">{customPriceError}</p>{/if}
          </div>
          
          <div class="custom-prices-list">
            <h4>Existing Custom Prices</h4>
            <div class="table-responsive">
              <table>
                <thead><tr><th>User</th><th>Price</th><th>Action</th></tr></thead>
                <tbody>
                  {#each customPrices as cp}
                    <tr>
                      <td>{cp.display_name || cp.email}</td>
                      <td>R{cp.custom_price}</td>
                      <td><button class="delete-btn small" on:click={() => removeCustomPrice(String(cp.id))}>Remove</button></td>
                    </tr>
                  {/each}
                  {#if customPrices.length === 0}
                    <tr><td colspan="3" class="empty-state">No custom prices have been set for this product.</td></tr>
                  {/if}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
  {/if}
</div>

<style>
  /* Using a subset of styles from the original admin page */
  .product-management-page { max-width: 1400px; margin: 0 auto; padding: 2rem;margin-top: 15px }
  .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
  .section-header h2 { margin: 0; color: #333; font-size: 1.5rem; }
  .filters-card, .form-card, .table-card { background: white; padding: 1.5rem; border-radius: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); margin-bottom: 1.5rem; }
  .filters-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; }
  .filter-group { display: flex; flex-direction: column; gap: 0.5rem; }
  .filter-group label { font-size: 0.9rem; color: #666; font-weight: 500; }
  .filter-group input, .filter-group select { padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-size: 0.9rem; }
  .primary-btn { 
    background: linear-gradient(to right, #0062E6, #33AEFF);
    color: white; 
    padding: 0.6rem 1.2rem; 
    border: none; 
    border-radius: 8px;
    font-size: 0.95rem; 
    font-weight: 500;
    cursor: pointer; 
    transition: all 0.2s ease;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }
  .primary-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 6px rgba(0,0,0,0.15);
  }
  .edit-btn, .delete-btn { padding: 0.75rem 1.5rem; border: none; border-radius: 6px; font-size: 1rem; cursor: pointer; transition: all 0.2s; }
  .edit-btn { background: #ffc107; color: #212529; padding: 0.5rem 1rem; }
  .delete-btn { background: #dc3545; color: white; padding: 0.5rem 1rem; }
  .table-responsive { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; min-width: 600px; }
  th, td { padding: 1rem; text-align: left; border-bottom: 1px solid #e9ecef; }
  th { background: #f8f9fa; color: #495057; font-weight: 600; }
  .product-thumbnail { width: 50px; height: 50px; object-fit: cover; border-radius: 4px; }
  .action-buttons { display: flex; gap: 0.5rem; }
  .tag-badge { display: inline-block; padding: 0.2em 0.6em; margin-right: 0.3em; border-radius: 8px; font-size: 0.85em; font-weight: 600; color: #fff; }
  .tag-badge.new { background: #007bff; }
  .tag-badge.special { background: #e67e22; }
  .modal-backdrop { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.4); z-index: 2000; }
  .modal { /* Simplified for brevity */ position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #fff; padding: 2rem; border-radius: 12px; z-index: 3001; }

  .custom-prices-modal {
    display: flex;
    flex-direction: column;
    max-width: 600px;
    width: 90vw;
    max-height: 80vh;
    background: #f8f9fa;
    padding: 0;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 5px 15px rgba(0,0,0,0.3);
  }

  .custom-prices-modal .modal-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 1rem 1.5rem;
      border-bottom: 1px solid #e9ecef;
      background: white;
  }

  .custom-prices-modal .modal-header h3 {
      margin: 0;
      font-size: 1.25rem;
      color: #343a40;
  }

  .custom-prices-modal .close-btn {
      background: none;
      border: none;
      font-size: 2rem;
      line-height: 1;
      color: #6c757d;
      cursor: pointer;
      padding: 0;
  }

  .custom-prices-modal .modal-body {
      padding: 1.5rem;
      overflow-y: auto;
  }

  .add-custom-price-form {
      background: white;
      padding: 1.5rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }

  .search-wrapper {
      position: relative;
  }

  .user-search-results {
      list-style: none;
      padding: 0;
      margin: 0.5rem 0 0 0;
      border: 1px solid #ddd;
      border-radius: 4px;
      max-height: 150px;
      overflow-y: auto;
  }
  .user-search-results li {
      padding: 0.75rem;
      cursor: pointer;
  }
  .user-search-results li:hover, .user-search-results li:focus {
      background: #f1f3f5;
  }

  .selected-user-info {
      margin: 1rem 0;
      padding: 0.75rem;
      background: #e9f7ff;
      border-radius: 4px;
      border: 1px solid #b3e0ff;
  }

  .price-input-group {
      display: flex;
      gap: 0.5rem;
  }
  .price-input-group input {
      flex-grow: 1;
  }
  .price-input-group .primary-btn {
    padding: 0.5rem 1rem;
    font-size: 0.9rem;
  }

  .error-message {
      color: #dc3545;
      font-size: 0.9rem;
      margin-top: 0.5rem;
  }

  .custom-prices-list h4 {
      margin-bottom: 1rem;
      color: #333;
  }

  .delete-btn.small {
      padding: 0.25rem 0.5rem;
      font-size: 0.8rem;
  }

  .empty-state {
      text-align: center;
      padding: 2rem;
      color: #666;
  }
  
  @media (max-width: 768px) {
      .custom-prices-modal {
          width: 95vw;
          max-height: 90vh;
      }
  }
</style> 