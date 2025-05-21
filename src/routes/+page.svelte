<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  import { cartStore } from '$lib/stores/cartStore';
  import { fetchProducts, fetchProductsLazy } from '$lib/services/productService';
  import { supabase } from '$lib/supabase';
  import type { Product } from '$lib/types';
  
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import ProductCard from '$lib/components/ProductCard.svelte';
  import CartSidebar from '$lib/components/CartSidebar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';
  import ProductDetailsModal from '$lib/components/ProductDetailsModal.svelte';
  import StarryBackground from '$lib/components/StarryBackground.svelte';

  let products: Product[] = [];
  let filteredProducts: Product[] = [];
  let cartVisible = false;
  let menuVisible = false;
  let loading = false;
  let loadingMore = false;
  let error: string | null = null;
  let activeCategory: string | undefined = undefined;
  let logoUrl = '';
  let isPosUser = false;
  let selectedProduct: Product | null = null;
  let currentPage = 1;
  let hasMore = false;
  let observer: IntersectionObserver;
  let loadMoreTrigger: HTMLElement;
  let totalProducts = 0;
  let pageSize = 4; // Default to tablet view
  let debounceTimer: NodeJS.Timeout;
  let isFetching = false;
  let lastScrollY = 0;
  let scrollDirection: 'up' | 'down' = 'down';
  let scrollTimeout: NodeJS.Timeout;
  let loadedPages = new Set<number>(); // Track which pages we've already loaded

  const categoryNames: Record<string, string> = {
    'flower': 'Flower',
    'concentrate': 'Extracts',
    'joints': 'Joints',
    'edibles': 'Edibles',
    'headshop': 'Headshop'
  };

  // Category-specific background images
  const categoryBackgrounds: Record<string, string> = {
    home: "https://cannabisimages.co.uk/wp-content/uploads/2023/07/cannabis-plants-sunset-2-scaled.jpeg",
    flower: "https://m.foolcdn.com/media/dubs/original_images/Slide_7_-_marijuana_greenhouse.jpg",
    concentrate: "https://bulkweedinbox.cc/wp-content/uploads/2024/12/Greasy-Pink.jpg",
    joints: "https://mjbizdaily.com/wp-content/uploads/2024/08/Pre-rolls_-joints-_2_.webp",
    edibles: "https://longislandinterventions.com/wp-content/uploads/2024/12/Edibles-1.jpg",
    headshop: "https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//bongs.webp"
  };

  // Icon mapping for categories
  const categoryIcons: Record<string, string> = {
    joints: 'fa-joint',
    concentrate: 'fa-vial',
    flower: 'fa-cannabis',
    edibles: 'fa-cookie',
    headshop: 'fa-store'
  };

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
  }

  function handleScroll() {
    const currentScrollY = window.scrollY;
    // Only update direction if the change is significant (more than 5px)
    if (Math.abs(currentScrollY - lastScrollY) > 5) {
      scrollDirection = currentScrollY > lastScrollY ? 'down' : 'up';
      lastScrollY = currentScrollY;
    }

    // Clear any existing timeout
    if (scrollTimeout) {
      clearTimeout(scrollTimeout);
    }

    // Set a new timeout to update scroll direction
    scrollTimeout = setTimeout(() => {
      scrollDirection = 'down'; // Reset to default after scrolling stops
    }, 300); // Increased from 150ms to 300ms for more stability
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
      
      // Only reload if page size actually changed
      if (oldPageSize !== pageSize && activeCategory) {
        currentPage = 1;
        loadProducts(activeCategory, 1);
      }
    }, 500); // Wait 500ms after resize stops before updating
  }

  function handleIntersection(entries: IntersectionObserverEntry[]) {
    const target = entries[0];
    // Only trigger if:
    // 1. Element is intersecting
    // 2. We have more products to load
    // 3. We're not currently loading
    // 4. We're not fetching
    // 5. We have an active category
    // 6. We're scrolling down (prevents triggers during bounce/overscroll)
    if (target.isIntersecting && 
        hasMore && 
        !loadingMore && 
        !isFetching && 
        activeCategory && 
        scrollDirection === 'down') {
      
      // Clear any existing timer
      if (debounceTimer) {
        clearTimeout(debounceTimer);
      }
      
      // Set a new timer with increased debounce time for mobile
      debounceTimer = setTimeout(() => {
        console.log('Triggering load more:', { 
          currentPage, 
          hasMore, 
          currentProducts: products.length,
          scrollDirection
        });
        loadProducts(activeCategory, currentPage + 1);
      }, 500); // Increased from 300ms to 500ms for better mobile handling
    }
  }

  async function loadProducts(category?: string, page: number = 1) {
    if (!category || isFetching) return;
    
    // If we've already loaded this page, don't fetch again
    if (loadedPages.has(page)) {
      console.log('Page already loaded:', page);
      return;
    }
    
    if (page === 1) {
      loading = true;
      error = null;
      products = [];
      loadedPages.clear(); // Clear loaded pages when changing category
    } else {
      loadingMore = true;
    }

    isFetching = true;

    try {
      const result = await fetchProductsLazy(category, page, pageSize);
      
      if (page === 1) {
        products = result.products;
      } else {
        products = [...products, ...result.products];
      }
      
      hasMore = result.hasMore;
      error = result.error;
      currentPage = page;
      loadedPages.add(page); // Mark this page as loaded
      
      console.log('Products loaded:', {
        page,
        pageSize,
        productsCount: products.length,
        hasMore,
        currentProducts: products.length,
        loadedPages: Array.from(loadedPages)
      });
    } catch (err) {
      console.error('Error loading products:', err);
      error = 'Failed to load products. Please try again.';
    } finally {
      loading = false;
      loadingMore = false;
      isFetching = false;
    }
  }

  function handleRetry() {
    if (activeCategory) {
      currentPage = 1;
      loadedPages.clear(); // Clear loaded pages on retry
      loadProducts(activeCategory, 1);
    }
  }

  onMount(async () => {
    try {
      const { data } = supabase.storage.from('route420').getPublicUrl('logo.png');
      logoUrl = data.publicUrl;
    } catch (err) {
      console.error('Error getting logo URL:', err);
    }

    // Fetch current user's profile to check for POS role
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('auth_user_id', user.id)
        .single();
      if (profile && profile.role === 'pos') {
        isPosUser = true;
      }
    }

    // Only run browser-specific code if window is defined
    if (typeof window !== 'undefined') {
      Object.values(categoryBackgrounds).forEach(url => {
        const img = new window.Image();
        img.src = url;
      });

      // Initial page size update
      updatePageSize();

      // Listen for window resize with debounce
      window.addEventListener('resize', handleResize);

      // Add scroll listener
      window.addEventListener('scroll', handleScroll, { passive: true });

      // Setup intersection observer for infinite scroll with more conservative settings
      observer = new IntersectionObserver(handleIntersection, {
        root: null,
        rootMargin: '400px',
        threshold: 0.1
      });
    }
  });

  // Cleanup observer, timer, and scroll listener on component destroy
  onDestroy(() => {
    if (typeof window !== 'undefined') {
      if (observer) {
        observer.disconnect();
      }
      if (debounceTimer) {
        clearTimeout(debounceTimer);
      }
      if (scrollTimeout) {
        clearTimeout(scrollTimeout);
      }
      if (resizeTimeout) {
        clearTimeout(resizeTimeout);
      }
      window.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', handleResize);
    }
  });

  // Update observer when loadMoreTrigger changes
  $: if (loadMoreTrigger && observer) {
    observer.observe(loadMoreTrigger);
  }

  $: if (activeCategory) {
    currentPage = 1;
    loadedPages.clear();
    loadProducts(activeCategory);
  } else {
    products = [];
    filteredProducts = [];
    hasMore = false;
    loadedPages.clear();
  }

  $: filteredProducts = products;

  $: categoryBackgroundStyle = '';

  function addToCart(e: CustomEvent) {
    const product = e.detail;
    cartStore.addItem(product);
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
/>

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
      <button on:click={handleRetry} class="retry-btn">
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
    <div class="category-section">
      <div class="category-header">
        {#if activeCategory && categoryIcons[activeCategory]}
          <i class="fa-solid {categoryIcons[activeCategory]} category-header-icon"></i>
        {/if}
      </div>
      <div class="products-grid">
        {#each filteredProducts as product (product.id)}
          <div in:fly={{ y: 30, duration: 350 }}>
            <ProductCard {product} on:addToCart={addToCart} on:showdetails={handleShowDetails} />
          </div>
        {/each}
      </div>
      {#if loadingMore && !isFetching}
        <div class="loading-more">
          <LoadingSpinner size="24px" />
          <p>Loading more...</p>
        </div>
      {/if}
      {#if hasMore && !loadingMore}
        <div class="load-more-trigger" bind:this={loadMoreTrigger}></div>
      {/if}
    </div>
  {/if}
</main>

<!-- Cart Sidebar Component -->
<CartSidebar visible={cartVisible} toggleVisibility={toggleCart} isPosUser={isPosUser} />

<!-- Side Menu Component -->
<SideMenu 
  visible={menuVisible} 
  toggleVisibility={toggleMenu}
  on:selectcategory={e => activeCategory = e.detail.id}
/>

{#if selectedProduct}
  <ProductDetailsModal product={selectedProduct} on:close={closeProductModal} />
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
    background: rgba(0, 0, 0, 0.7);
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
    padding-bottom: 200px; /* Add padding to ensure trigger is always in view */
  }

  @media (max-width: 1024px) {
    .products-grid {
      grid-template-columns: repeat(3, 1fr);
      gap: 1rem;
    }
  }

  @media (max-width: 768px) {
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

  @media (max-width: 1440px) {
    .products-container {
      padding-left: 1.5rem;
      padding-right: 1.5rem;
      min-height: calc(100vh - 120px);
      padding-top: 20px;
    }
  }
  
  @media (max-width: 768px) {
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
    background: #fff;
  }

  :global(*) {
    position: relative;
    z-index: 1;
  }

  .category-header-icon {
    font-size: 2.5rem;
    color: #007bff;
    display: block;
    text-align: center;
    
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
    height: 200px; /* Increased height for earlier triggering */
    width: 100%;
    position: relative;
    z-index: -1; /* Ensure it doesn't interfere with other elements */
  }
</style>
