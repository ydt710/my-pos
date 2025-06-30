<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import type { Product } from '$lib/types/index';
  import { showSnackbar } from '$lib/stores/snackbarStore';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import ProductEditModal from '$lib/components/ProductEditModal.svelte';
  import { getShopStockLevels } from '$lib/services/stockService';
  import { fetchProducts as fetchProductsFromService, clearAllProductCache } from '$lib/services/productService';
  import { PUBLIC_SHOP_LOCATION_ID } from '$env/static/public';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import { getProductImage } from '$lib/constants';

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
    is_special: false,
    is_out_of_stock: false,
    low_stock_buffer: 1000
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
    // Clear all product cache to ensure fresh data
    clearAllProductCache();
    
    const { products: fetchedProducts, error: err } = await fetchProductsFromService();
    loading = false;
    
    if (err) {
      error = err;
    } else {
      products = fetchedProducts.map(p => ({ ...p, id: String(p.id) })) as Product[];
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
              // Create stock_levels entries for all locations
              const { data: locations, error: locError } = await supabase
                .from('stock_locations')
                .select('id');
              
              if (!locError && locations) {
                const stockLevelEntries = locations.map(location => ({
                  product_id: data.id,
                  location_id: location.id,
                  quantity: 0
                }));
                
                const { error: stockError } = await supabase
                  .from('stock_levels')
                  .insert(stockLevelEntries);
                
                if (stockError) {
                  console.error('Error creating stock levels:', stockError);
                  error = 'Product created but failed to initialize stock levels';
                }
              }
            }
        }
        imageFile = null;
        uploadProgress = 0;
        closeEditModal();
        // Clear cache and refresh data
        clearAllProductCache();
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
      // Clear cache and refresh data
      clearAllProductCache();
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
    if (!selectedCustomPriceUser || !editing || newCustomPrice === '' || newCustomPrice === null || newCustomPrice === undefined) {
      customPriceError = 'Select a user and enter a price.';
      return;
    }
    const priceValue = Number(newCustomPrice);
    if (isNaN(priceValue) || priceValue < 0) {
      customPriceError = 'Please enter a valid price (0 or greater).';
      return;
    }
    const { error } = await supabase
      .from('user_product_prices')
      .upsert([
        { user_id: selectedCustomPriceUser.id, product_id: String(editing.id), custom_price: priceValue }
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

<StarryBackground />

<main class="admin-main">
  <div class="admin-container">
    <div class="admin-header">
      <h2 class="neon-text-cyan">Product Management</h2>
      <div class="flex gap-2">
        <button class="btn btn-primary" on:click={openAddModal}>+ Add Product</button>
      </div>
    </div>

    <div class="glass mb-4">
      <div class="card-body">
        <div class="admin-grid admin-grid-3">
          <div class="form-group">
            <label for="search" class="form-label">Search</label>
            <input id="search" type="text" placeholder="Search products..." bind:value={productFilters.search} on:input={applyProductFilters} class="form-control"/>
          </div>
          <div class="form-group">
            <label for="category" class="form-label">Category</label>
            <select id="category" bind:value={productFilters.category} on:change={applyProductFilters} class="form-control form-select">
              <option value="">All Categories</option>
              {#each categories as category}
                <option value={category.id}>{category.name}</option>
              {/each}
            </select>
          </div>
          <div class="form-group">
            <label for="minPrice" class="form-label">Min Price</label>
            <input id="minPrice" type="number" min="0" step="0.01" placeholder="Min price" bind:value={productFilters.minPrice} on:input={applyProductFilters} class="form-control"/>
          </div>
          <div class="form-group">
            <label for="maxPrice" class="form-label">Max Price</label>
            <input id="maxPrice" type="number" min="0" step="0.01" placeholder="Max price" bind:value={productFilters.maxPrice} on:input={applyProductFilters} class="form-control"/>
          </div>
          <div class="form-group">
            <label for="sortBy" class="form-label">Sort By</label>
            <select id="sortBy" bind:value={productFilters.sortBy} on:change={applyProductFilters} class="form-control form-select">
              <option value="name">Name</option>
              <option value="price">Price</option>
              <option value="category">Category</option>
            </select>
          </div>
          <div class="form-group">
            <label for="sortOrder" class="form-label">Order</label>
            <select id="sortOrder" bind:value={productFilters.sortOrder} on:change={applyProductFilters} class="form-control form-select">
              <option value="asc">Ascending</option>
              <option value="desc">Descending</option>
            </select>
          </div>
        </div>
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
    
    <div class="glass">
      <!-- Desktop Table View -->
      <div class="table-responsive desktop-only">
        <table class="table-dark">
          <thead>
            <tr>
              <th>Image</th><th>Name</th><th>Category</th><th>Price</th><th>Tags</th><th>Stock</th><th>Buffer</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {#each filteredProducts as product (product.id)}
              <tr class="hover-glow">
                <td><img src={getProductImage(product.image_url, product.category)} alt={product.name} class="product-thumbnail"/></td>
                <td class="neon-text-white">{product.name}</td>
                <td>{categories.find(c => String(c.id) === String(product.category))?.name || product.category}</td>
                <td class="neon-text-cyan">
                  {#if product.is_special && product.special_price}
                    <span style="text-decoration: line-through; color: #888;">R{product.price}</span>
                    <span style="color: #e67e22; font-weight: bold; margin-left: 0.5em;">R{product.special_price}</span>
                  {:else}
                    R{product.price}
                  {/if}
                </td>
                <td>
                  {#if product.is_new}<span class="badge badge-info">New</span>{/if}
                  {#if product.is_special}<span class="badge badge-warning">Special</span>{/if}
                  {#if product.is_out_of_stock}<span class="badge badge-danger">Out of Stock</span>{/if}
                </td>
                <td class="neon-text-cyan">
                  {stockLevels[product.id] ?? 0}
                  {#if !product.is_out_of_stock && (product.low_stock_buffer ?? 0) > 0 && (stockLevels[product.id] ?? 0) <= (product.low_stock_buffer ?? 0)}
                    <span class="low-stock-indicator" title="Low stock alert">⚠️</span>
                  {/if}
                </td>
                <td class="neon-text-muted">{product.low_stock_buffer ?? 1000}</td>
                <td>
                  <div class="flex gap-1">
                    <button class="btn btn-secondary btn-sm" on:click={() => openEditModal(product)}>Edit</button>
                    <button class="btn btn-danger btn-sm" on:click={() => { showProductConfirmModal = true; productIdToDelete = String(product.id); }}>Delete</button>
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

             <!-- Mobile Card View -->
       <div class="admin-grid mobile-only">
         {#each filteredProducts as product (product.id)}
           <div class="admin-card product-card">
             <div class="admin-card-header">
               <img src={getProductImage(product.image_url, product.category)} alt={product.name} class="product-image"/>
               <div>
                 <div class="admin-card-title">{product.name}</div>
                 <div class="admin-card-subtitle">{categories.find(c => String(c.id) === String(product.category))?.name || product.category}</div>
               </div>
             </div>
             
             <div class="admin-card-body">
               <div class="product-price neon-text-cyan">
                 {#if product.is_special && product.special_price}
                   <span style="text-decoration: line-through; color: #888;">R{product.price}</span>
                   <span style="color: #e67e22; font-weight: bold; margin-left: 0.5em;">R{product.special_price}</span>
                 {:else}
                   R{product.price}
                 {/if}
               </div>
               
               <div class="product-tags badge-group-horizontal">
                 {#if product.is_new}<span class="badge badge-info">New</span>{/if}
                 {#if product.is_special}<span class="badge badge-warning">Special</span>{/if}
                 {#if product.is_out_of_stock}<span class="badge badge-danger">Out of Stock</span>{/if}
               </div>
               
               <div class="product-stock-info">
                 <div class="stock-item">
                   <span class="stock-label">Stock:</span>
                   <span class="neon-text-cyan">
                     {stockLevels[product.id] ?? 0}
                     {#if !product.is_out_of_stock && (product.low_stock_buffer ?? 0) > 0 && (stockLevels[product.id] ?? 0) <= (product.low_stock_buffer ?? 0)}
                       <span class="low-stock-indicator" title="Low stock alert">⚠️</span>
                     {/if}
                   </span>
                 </div>
                 <div class="stock-item">
                   <span class="stock-label">Buffer:</span>
                   <span class="neon-text-muted">{product.low_stock_buffer ?? 1000}</span>
                 </div>
               </div>
             </div>
             
             <div class="admin-card-actions">
               <button class="btn btn-secondary btn-sm" on:click={() => openEditModal(product)}>Edit</button>
               <button class="btn btn-danger btn-sm" on:click={() => { showProductConfirmModal = true; productIdToDelete = String(product.id); }}>Delete</button>
             </div>
           </div>
         {/each}
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
      <div class="modal-backdrop custom-prices-backdrop" role="button" on:click={() => showCustomPrices = false}></div>
      <div class="modal-content custom-prices-modal" role="dialog" aria-modal="true">
        <div class="modal-header">
          <h3 class="neon-text-cyan">Custom Prices for {editing.name}</h3>
          <button class="modal-close" on:click={() => showCustomPrices = false}>&times;</button>
        </div>
        <div class="modal-body">
          <div class="glass-light p-3 mb-3">
            <div class="form-group">
              <label for="user-search" class="form-label">Search for a user</label>
              <div class="search-wrapper">
                <input id="user-search" type="text" placeholder="Search by name or email..." bind:value={customPriceUserSearch} on:input={searchCustomPriceUsers} class="form-control" />
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
              <div class="selected-user-info glass-light p-2 mb-2">
                Selected: <strong class="neon-text-cyan">{selectedCustomPriceUser.display_name || selectedCustomPriceUser.email}</strong>
              </div>
            {/if}
            
            <div class="form-group">
              <label for="new-custom-price" class="form-label">Set Custom Price (R)</label>
              <div class="flex gap-2">
                <input id="new-custom-price" type="number" min="0" step="0.01" placeholder="Enter price" bind:value={newCustomPrice} class="form-control" />
                <button class="btn btn-primary" on:click={addCustomPrice}>Add Price</button>
              </div>
            </div>
            {#if customPriceError}<div class="alert alert-danger">{customPriceError}</div>{/if}
          </div>
          
          <div class="custom-prices-list">
            <h4 class="neon-text-cyan mb-2">Existing Custom Prices</h4>
            <table class="table-dark">
              <thead>
                <tr><th>User</th><th>Price</th><th>Action</th></tr>
              </thead>
              <tbody>
                {#each customPrices as cp}
                  <tr>
                    <td>{cp.display_name || cp.email}</td>
                    <td class="neon-text-cyan">R{cp.custom_price}</td>
                    <td><button class="btn btn-danger btn-sm" on:click={() => removeCustomPrice(String(cp.id))}>Remove</button></td>
                  </tr>
                {/each}
                {#if customPrices.length === 0}
                  <tr><td colspan="3" class="text-center text-muted">No custom prices have been set for this product.</td></tr>
                {/if}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    {/if}
  </div>
</main>

<style>
  .admin-main {
    min-height: 100vh;
    padding-top: 80px;
    background: transparent;
  }

  .admin-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
    margin-top: 6pc;
  }

  .admin-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  .admin-header h2 {
    margin: 0;
    font-size: 1.5rem;
  }

  .product-thumbnail {
    width: 50px;
    height: 50px;
    object-fit: cover;
    border-radius: 4px;
    border: 1px solid var(--border-primary);
  }

  .custom-prices-backdrop {
    z-index: 4000;
  }

  .custom-prices-modal {
    max-width: 600px;
    width: 90vw;
    max-height: 80vh;
    z-index: 4001;
  }

  :global(.modal-content) {
    position: fixed !important;
    top: 50% !important;
    left: 50% !important;
    transform: translate(-50%, -50%) !important;
    margin: 0 !important;
    z-index: 100000 !important;
    max-width: 90vw !important;
    max-height: 90vh !important;
    overflow-y: auto !important;
  }

  .search-wrapper {
    position: relative;
  }

  .user-search-results {
    list-style: none;
    padding: 0;
    margin: 0.5rem 0 0 0;
    border: 1px solid var(--border-primary);
    border-radius: 4px;
    max-height: 150px;
    overflow-y: auto;
    background: var(--bg-secondary);
  }

  .user-search-results li {
    padding: 0.75rem;
    cursor: pointer;
    color: var(--text-primary);
    border-bottom: 1px solid var(--border-primary);
  }

  .user-search-results li:hover,
  .user-search-results li:focus {
    background: var(--bg-glass-light);
    color: var(--neon-cyan);
  }

  .user-search-results li:last-child {
    border-bottom: none;
  }

  .selected-user-info {
    border: 1px solid var(--neon-cyan);
    border-radius: 4px;
  }

  .custom-prices-list h4 {
    margin-bottom: 1rem;
  }

  .text-muted {
    color: var(--text-muted);
  }

  .low-stock-indicator {
    margin-left: 0.5rem;
    font-size: 0.9rem;
    animation: pulse-warning 2s infinite;
  }

  @keyframes pulse-warning {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  /* Component-specific styles only */

  @media (max-width: 768px) {
    .admin-container {
      padding: 1rem;
    }
    
    .admin-header {
      flex-direction: column;
      gap: 1rem;
      align-items: stretch;
    }
    
    .custom-prices-modal {
      width: 95vw;
      max-height: 90vh;
    }

    .grid-3 {
      grid-template-columns: 1fr;
    }
  }

  @media (max-width: 1024px) and (min-width: 769px) {
    .product-thumbnail {
      width: 40px;
      height: 40px;
    }
    
    .btn-sm {
      padding: 0.25rem 0.5rem;
      font-size: 0.8rem;
    }
  }
</style> 