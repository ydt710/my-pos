<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  import { cartStore } from '$lib/stores/cartStore';
  import { productsStore, loadAllProducts } from '$lib/services/productService';
  import { supabase } from '$lib/supabase';
  import type { Product } from '$lib/types/index';
  
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import ProductCard from '$lib/components/ProductCard.svelte';
  import CartSidebar from '$lib/components/CartSidebar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';
  import ProductDetailsModal from '$lib/components/ProductDetailsModal.svelte';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import ProductReviewModal from '$lib/components/ProductReviewModal.svelte';
  import { getProductReviews, addReview, updateReview, updateProductRating } from '$lib/services/reviewService';
  import { getShopStockLevels } from '$lib/services/stockService';
  import { clearProductCache } from '$lib/services/cacheService';

  let allProducts: Product[] = [];
  let products: Product[] = [];
  let cartVisible = false;
  let menuVisible = false;
  let loading = false;
  let error: string | null = null;
  let activeCategory: string | undefined = undefined;
  let logoUrl = '';
  let isPosUser = false;
  let selectedProduct: Product | null = null;
  let pageSize = 4; // Default to tablet view
  let currentPage = 1;
  let totalProducts = 0;
  let paginatedProducts: Product[] = [];
  let showReviewModal = false;
  let reviewProduct: Product | null = null;
  let userReview: any = null;
  let newReview = { rating: 5, comment: '' };
  let submittingReview = false;
  let stockLevels: { [productId: string]: number } = {};

  let productFilters = {
    search: '',
    category: '',
    minPrice: '',
    maxPrice: '',
    sortBy: 'name',
    sortOrder: 'asc'
  };

  const categoryNames: Record<string, string> = {
    'flower': 'Flower',
    'concentrate': 'Extracts',
    'joints': 'Joints',
    'edibles': 'Edibles',
    'headshop': 'Headshop'
  };

  // Icon mapping for categories
  const categoryIcons: Record<string, string> = {
    joints: 'fa-joint',
    concentrate: 'fa-vial',
    flower: 'fa-cannabis',
    edibles: 'fa-cookie',
    headshop: 'fa-store'
  };

  let unsubscribe: (() => void) | undefined;

  let loadMoreTrigger: HTMLDivElement | null = null;
  let observer: IntersectionObserver | null = null;

  function setupObserver() {
    if (observer) observer.disconnect();
    observer = new window.IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        loadMoreProducts();
      }
    }, { threshold: 1.0 });
    if (loadMoreTrigger) observer.observe(loadMoreTrigger);
  }

  function loadMoreProducts() {
    // Only load more if there are more products to show
    if (currentPage * pageSize < products.length) {
      currentPage += 1;
      paginateProducts();
    }
  }

  // Function to determine page size based on viewport width
  function updatePageSize() {
    const width = window.innerWidth;
    if (width < 600) { // Mobile
      pageSize = 2;
    } else if (width < 1024) { // Tablet
      pageSize = 4;
    } else { // Desktop
      pageSize = 8;
    }
    console.log('Updated page size:', { width, pageSize });
    paginateProducts();
  }

  function filterProducts() {
    // Always search out of allProducts array
    products = allProducts
      .filter(p => {
        const matchesSearch = productFilters.search
          ? p.name.toLowerCase().includes(productFilters.search.toLowerCase())
          : true;
        // If searching, ignore category filter
        const matchesCategory = productFilters.search
          ? true
          : (activeCategory ? p.category === activeCategory : true);
        return matchesCategory && matchesSearch;
      })
      .sort((a, b) => a.name.localeCompare(b.name));
    totalProducts = products.length;
    paginateProducts();
  }

  function paginateProducts() {
    const end = currentPage * pageSize;
    paginatedProducts = products.slice(0, end);
  }

  function handleCategoryChange(category: string) {
    activeCategory = category;
    currentPage = 1;
    filterProducts();
  }

  function handlePageChange(page: number) {
    currentPage = page;
    paginateProducts();
  }

  // Debounced resize handler
  let resizeTimeout: NodeJS.Timeout;
  function handleResize() {
    if (resizeTimeout) {
      clearTimeout(resizeTimeout);
    }
    resizeTimeout = setTimeout(() => {
      const oldPageSize = pageSize;
      updatePageSize();
      if (oldPageSize !== pageSize) {
        currentPage = 1;
        paginateProducts();
      }
    }, 500);
  }

  onMount(async () => {
    try {
      const { data } = supabase.storage.from('route420').getPublicUrl('logo.webp');
      logoUrl = data.publicUrl;
    } catch (err) {
      console.error('Error getting logo URL:', err);
    }

    // Fetch current user's profile to check for POS role
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('auth_user_id', user.id)
        .maybeSingle();
      if (profileError && profileError.code !== 'PGRST116' && profileError.code !== '406') {
        console.error('Error fetching profile:', profileError);
      }
      if (profile && profile.role === 'pos') {
        isPosUser = true;
      }
    }

    // Load all products once and subscribe to the store
    loading = true;
    const { error: loadError } = await loadAllProducts();
    loading = false;
    if (loadError) {
      error = loadError;
    }
    unsubscribe = productsStore.subscribe(async p => {
      allProducts = p;
      filterProducts();
      // Fetch stock levels for all products
      if (allProducts.length > 0) {
        stockLevels = await getShopStockLevels(allProducts.map(prod => prod.id));
      } else {
        stockLevels = {};
      }
    });

    if (typeof window !== 'undefined') {
      updatePageSize();
      window.addEventListener('resize', handleResize);
    }
  });

  onDestroy(() => {
    if (unsubscribe) unsubscribe();
    if (typeof window !== 'undefined') {
      if (resizeTimeout) {
        clearTimeout(resizeTimeout);
      }
      window.removeEventListener('resize', handleResize);
    }
    if (observer) observer.disconnect();
  });

  $: filteredProducts = paginatedProducts;

  $: categoryBackgroundStyle = '';

  function addToCart(e: CustomEvent) {
    const product = e.detail;
    
    cartVisible = true;
  }

  function toggleCart() {
    cartVisible = !cartVisible;
    if (menuVisible) menuVisible = false;
  }

  function toggleMenu() {
    menuVisible = !menuVisible;
    if (cartVisible) cartVisible = false;
  }

  function handleLogoClick() {
    activeCategory = '';
  }

  function handleShowDetails(event: CustomEvent<{product: Product}>) {
    selectedProduct = event.detail.product;
  }

  function closeProductModal() {
    selectedProduct = null;
  }

  async function openReviewModal(event: CustomEvent<{product: Product}>) {
    reviewProduct = event.detail.product;
    showReviewModal = true;
    // Load reviews for this product and set userReview/newReview
    const reviews = await getProductReviews(String(reviewProduct.id));
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      userReview = reviews.find((review: any) => review.user_id === user.id) || null;
      if (userReview) {
        newReview = { rating: userReview.rating, comment: userReview.comment };
      } else {
        newReview = { rating: 5, comment: '' };
      }
    }
  }

  function closeReviewModal() {
    showReviewModal = false;
    reviewProduct = null;
    userReview = null;
    newReview = { rating: 5, comment: '' };
  }

  function setReviewRating(rating: number) {
    newReview = { ...newReview, rating };
  }

  function setReviewComment(comment: string) {
    newReview = { ...newReview, comment };
  }

  async function submitReview() {
    if (submittingReview || !reviewProduct) return;
    submittingReview = true;
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        alert('Please sign in to leave a review');
        return;
      }
      if (userReview) {
        // Update existing review
        await updateReview(userReview.id, {
          rating: newReview.rating,
          comment: newReview.comment
        });
      } else {
        // Create new review
        await addReview({
          product_id: String(reviewProduct.id),
          user_id: user.id,
          rating: newReview.rating,
          comment: newReview.comment
        });
      }
      await updateProductRating(String(reviewProduct.id));
      closeReviewModal();
      clearProductCache(); // Clear cache before reloading products
      await loadAllProducts(); // Refresh products so product card updates
    } catch (error) {
      alert('Failed to submit review. Please try again.');
    } finally {
      submittingReview = false;
    }
  }

  function applyProductFilters() {
    filteredProducts = products.filter(product => {
      // Search filter
      if (productFilters.search && !product.name.toLowerCase().includes(productFilters.search.toLowerCase())) {
        return false;
      }
      // Category filter
      if (productFilters.category && product.category !== productFilters.category) {
        return false;
      }
      // Price range filter
      if (productFilters.minPrice && product.price < Number(productFilters.minPrice)) {
        return false;
      }
      if (productFilters.maxPrice && product.price > Number(productFilters.maxPrice)) {
        return false;
      }
      return true;
    });
    // Apply sorting
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

  $: if (typeof window !== 'undefined' && loadMoreTrigger) {
    setupObserver();
  }
</script>

<!-- Add StarryBackground component at the top level -->
<StarryBackground />

<!-- Category Navigation -->
<CategoryNav 
  bind:activeCategory 
  logoUrl={logoUrl}
  onMenuToggle={toggleMenu}
  onCartToggle={toggleCart}
  onLogoClick={handleLogoClick}
  on:selectcategory={e => handleCategoryChange(e.detail.id)}
/>

<!-- Search Bar -->


<!-- Watermark -->
{#if !activeCategory}
  <div class="watermark" style="--logo-url: url('{logoUrl}')"></div>
{/if}

<!-- Main Content Area -->
<main class="products-container">
  
  {#if loading && currentPage === 1}
    <div class="loading-container">
      <LoadingSpinner size="60px" />
      <p>Loading products...</p>
    </div>
  {:else if error}
    <div class="error-container">
      <p class="error-message">{error}</p>
      <button on:click={() => location.reload()} class="retry-btn">
        Try Again
      </button>
    </div>
  {:else if !activeCategory}
    <div class="welcome-section">
      <div class="welcome-overlay"></div>
      {#if isPosUser}
        <h1>Welcome POS User</h1>
      {:else}
        <h1>Welcome to Route 420</h1>
      {/if}
      <div class="content">
        <p class="tagline">Family-Grown Cannabis, Crafted with Care</p>
        <div class="message">
          <p>At Route 420, we're more than just a dispensary – we're a family-run farm dedicated to cultivating the finest cannabis products. Our journey began with a simple passion for quality and a commitment to sustainable farming practices.</p>
          <p>Every product in our store is grown, harvested, and processed with the same care and attention we give to our own family. We believe in transparency, quality, and the power of nature's gifts.</p>
          <p>Join us on this journey and experience the difference that family-grown cannabis can make.</p>
        </div>
        <p class="select-category">Select a category above to browse our products</p>
      </div>
    </div>
  {:else if filteredProducts.length === 0}
    <div class="empty-container">
      <p>No products available in this category at this time.</p>
    </div>
  {:else}
        <div class="category-header">
      
          {#if productFilters.search}
            <i class="fa-solid fa-magnifying-glass category-header-icon"></i>
          {:else if activeCategory && categoryIcons[activeCategory]}
            <i class="fa-solid {categoryIcons[activeCategory]} category-header-icon"></i>
          {/if}
          <input
              type="text"
              class="search-bar"
              placeholder="Search products..."
              bind:value={productFilters.search}
              on:input={() => { filterProducts(); }}
              aria-label="Search products"
              autocomplete="off"
            />
          
        </div>
    <div class="category-section">
      
      
      <div class="products-grid">
        {#each filteredProducts as product (product.id)}
          <div in:fly={{ y: 30, duration: 350 }}>
            <ProductCard 
              {product}
              stock={stockLevels[product.id] ?? 0}
              on:addToCart={addToCart}
              on:showDetails={handleShowDetails}
              on:showReview={openReviewModal}
            />
          </div>
        {/each}
        <!-- Infinite scroll trigger -->
        {#if currentPage * pageSize < products.length}
          <div bind:this={loadMoreTrigger} class="load-more-trigger"></div>
        {/if}
      </div>
    </div>
  {/if}
</main>

<!-- Cart Sidebar Component -->
{#if cartVisible}
  <div class="cart-overlay" role="button" tabindex="0" aria-label="Close cart sidebar" on:click={() => cartVisible = false} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { cartVisible = false; } }} style="position: fixed; inset: 0; z-index: 1999; background: transparent;"></div>
{/if}
<CartSidebar visible={cartVisible} toggleVisibility={toggleCart} isPosUser={isPosUser} />

<!-- Side Menu Component -->
<SideMenu 
  visible={menuVisible} 
  toggleVisibility={toggleMenu}
  on:selectcategory={e => activeCategory = e.detail.id}
/>

{#if selectedProduct}
  <ProductDetailsModal product={selectedProduct} show={true} on:close={closeProductModal} />
{/if}

{#if showReviewModal && reviewProduct}
  <ProductReviewModal
    
    userReview={userReview}
    newReview={newReview}
    submittingReview={submittingReview}
    show={showReviewModal}
    onSubmit={submitReview}
    onClose={closeReviewModal}
    setRating={setReviewRating}
    setComment={setReviewComment}
  />
{/if}

<style>
  /* Reserve space for Navbar + CategoryNav at the top */
  
  .products-container {
    max-width: 1920px;
    margin-left: auto;
    margin-right: auto;
    position: relative;
    z-index: 1;
    padding-top: 20px;
  }

  .welcome-section {
    max-width: 800px;
    margin: 0 auto;
    text-align: center;
    padding: 2rem;
    border-radius: 16px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    position: relative;
    overflow: hidden;
    color: #fff;
    backdrop-filter: blur(10px);
  }

  .welcome-section .welcome-overlay {
    display: none; /* Remove the overlay since we have the starry background */
  }

  .welcome-section h1,
  .welcome-section .tagline,
  .welcome-section .message p,
  .welcome-section .select-category {
    color: #fff;
    text-shadow: 0 2px 8px rgba(0,0,0,0.25);
  }

  h1 {
    font-size: 2.5rem;
    color: #333;
    margin-bottom: 1rem;
    font-weight: 700;
  }

  .tagline {
    font-size: 1.5rem;
    color: #007bff;
    margin-bottom: 2rem;
    font-weight: 600;
  }

  .message {
    text-align: left;
    margin-bottom: 2rem;
  }

  .message p {
    font-size: 1.1rem;
    line-height: 1.6;
    color: #555;
    margin-bottom: 1rem;
  }

  .select-category {
    font-size: 1.2rem;
    color: #666;
    font-style: italic;
    margin-top: 2rem;
  }

  .category-title {
    text-align: center;
    margin-bottom: 2rem;
    font-size: 2rem;
    color: #333;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  .products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 1.5rem;
    padding: 1rem;
    padding-bottom: 2rem;
  }

  @media (max-width: 1024px) {
    .products-grid {
      grid-template-columns: repeat(3, 1fr);
      gap: 1rem;
    }
  }

  @media (max-width: 800px) {
    .products-grid {
      grid-template-columns: repeat(2, 1fr);
      gap: 1rem;
    }
  }

  @media (max-width: 480px) {
    .products-grid {
      grid-template-columns: repeat(1, 1fr);
      gap: 1rem;
    }
  }

  .loading-container,
  .error-container,
  .empty-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 60vh;
    text-align: center;
    padding: 2rem;
  }

  .error-message {
    color: #721c24;
    background-color: #f8d7da;
    padding: 1.5rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    font-size: 1.1rem;
    max-width: 600px;
  }

  .retry-btn {
    background: #007bff;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1.1rem;
    transition: background-color 0.2s;
  }

  .retry-btn:hover {
    background: #0056b3;
  }
  .category-header {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 1rem;
      padding: 0.5rem 0;
      margin-bottom: 1rem;
    }

  @media (max-width: 1440px) {
    .products-container {
      padding-left: 1.5rem;
      padding-right: 1.5rem;
      min-height: calc(100vh - 120px);
      padding-top: 20px;
    }
  }
  
  @media (max-width: 800px) {
    .products-container {
      padding-left: 1rem;
      padding-right: 1rem;
      min-height: calc(100vh - 120px);
      padding-top: 20px;
    }

    .welcome-section {
      padding: 1.5rem;
      margin: 0 1rem;
    }


    h1 {
      font-size: 2rem;
    }

    .tagline {
      font-size: 1.2rem;
    }

    .message p {
      font-size: 1rem;
    }
  }

  @media (max-width: 480px) {
    .products-container {
      padding-left: 0.5rem;
      padding-right: 0.5rem;
      min-height: calc(100vh - 120px);
      padding-top: 20px;
    }

    .welcome-section {
      padding: 1rem;
      margin: 0 0.5rem;
    }
  }

  :global(.category-nav) {
    position: sticky;
    top: 60px; /* Should match Navbar height */
    left: 0;
    right: 0;
    z-index: 10;

    box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  }

  /* Category section with background image and overlay */
  .category-section {
    position: relative;
    padding: 0.5rem 0;
    border-radius: 16px;
    overflow: hidden;
    
  }
  .category-section::before {
    display: none; /* Remove the overlay since we have the starry background */
  }
  .category-section > * {
    position: relative;
    z-index: 1;
  }

  :global(html), :global(body) {
    margin: 0;
    padding: 0;
    background: transparent;
  }

  :global(*) {
    position: relative;
    z-index: 1;
  }



  .loading-more {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 1rem;
    color: #666;
    font-size: 0.9rem;
    background: transparent;
    margin: 1rem 0;
    min-height: 50px;
  }

  .load-more-trigger {
    height: 60px;
    width: 100%;
    background: transparent;
  }

  .search-bar-container {
    display: flex;
    justify-content: center;
    align-items: center;
    margin: 1.5rem 0 0.5rem 0;
  }
  .search-bar {
    width: 100%;
    max-width: 400px;
    padding: 0.75rem 1rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
    background: #fff;
    color: #222;
    box-shadow: 0 2px 8px rgba(0,0,0,0.03);
    transition: border-color 0.2s;
  }
  .search-bar:focus {
    outline: none;
    border-color: #007bff;
    box-shadow: 0 0 0 2px rgba(0,123,255,0.10);
  }
  .category-header-icon {
    font-size: 2.5rem;
    color: #ced9e4;
    display: block;
    text-align: center;
    
  }

  .cart-overlay {
    position: fixed;
    inset: 0;
    z-index: 1999;
    background: transparent;
    cursor: pointer;
  }
</style>
