<script lang="ts">
  import { onMount, onDestroy, afterUpdate } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  import { cartStore, cartVisible as globalCartVisible, toggleCart as globalToggleCart } from '$lib/stores/cartStore';
  import { loadAllProducts } from '$lib/services/productService';
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
  import { clearAllProductCache } from '$lib/services/productService';
  import Footer from '$lib/components/Footer.svelte';
  import { debounce } from '$lib/utils';
  import { CATEGORY_ICONS, CATEGORY_BACKGROUNDS, CATEGORY_CONFIG, getProductImage } from '$lib/constants';

  // Landing page data
  let landingHero: any = null;
  let landingCategories: any = null;
  let landingStores: any = null;
  let landingFeaturedProducts: any = null;
  let landingTestimonials: any = null;
  let featuredProducts: Product[] = [];

  let allProducts: Product[] = [];
  let products: Product[] = [];
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
  let posCheckComplete = false;
  let activeCategoryIcon: { icon: string; color: string } | null = null;

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

  let unsubscribe: (() => void) | undefined;

  let loadMoreTrigger: HTMLDivElement | null = null;
  let observer: IntersectionObserver | null = null;

  let showMap = false;
  let googleMapsUrl = '';

  function toggleMap() {
    showMap = !showMap;
  }

  // Function to load landing page data
  async function loadLandingPageData() {
    try {
      // Load hero section
      const { data: heroData } = await supabase
        .from('landing_hero')
        .select('*')
        .limit(1)
        .maybeSingle();
      landingHero = heroData;

      // Load categories section
      const { data: categoriesData } = await supabase
        .from('landing_categories')
        .select('*')
        .limit(1)
        .maybeSingle();
      landingCategories = categoriesData;

      // Load stores section
      const { data: storesData } = await supabase
        .from('landing_stores')
        .select('*')
        .limit(1)
        .maybeSingle();
      landingStores = storesData;

      // Load featured products section
      const { data: featuredData } = await supabase
        .from('landing_featured_products')
        .select('*')
        .limit(1)
        .maybeSingle();
      landingFeaturedProducts = featuredData;

      // Load testimonials section
      const { data: testimonialsData } = await supabase
        .from('landing_testimonials')
        .select('*')
        .limit(1)
        .maybeSingle();
      landingTestimonials = testimonialsData;

      // Load Google Maps URL from settings
      const { data: settingsData } = await supabase
        .from('settings')
        .select('google_maps_embed_url')
        .limit(1)
        .maybeSingle();
      googleMapsUrl = settingsData?.google_maps_embed_url || 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3318.3044078274843!2d18.96933201180263!3d-33.72694127316965!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x1dcda8218f2d8a8b%3A0x65417bfb9430d0bf!2s7%20Mernoleon%20St%2C%20Lemoenkloof%2C%20Paarl%2C%207646!5e0!3m2!1sen!2sza!4v1750808736378!5m2!1sen!2sza';

      // Load featured products if product IDs are specified
      if (landingFeaturedProducts?.product_ids?.length > 0) {
        const { data: products } = await supabase
          .from('products')
          .select('*')
          .in('id', landingFeaturedProducts.product_ids)
          .limit(8);
        featuredProducts = products || [];
      } else {
        // Fallback: show 4 random products
        const { data: randomProducts } = await supabase
          .from('products')
          .select('*')
          .limit(4);
        featuredProducts = randomProducts || [];
      }
    } catch (err) {
      console.error('Error loading landing page data:', err);
    }
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
  }

  function filterProducts() {
    // Disconnect and destroy the old observer before filtering
    if (observer) {
      observer.disconnect();
      observer = null;
    }
    // Always search out of allProducts array
    products = allProducts
      .filter(p => {
        // If no search term, only apply category filter
        if (!productFilters.search) {
          return activeCategory ? p.category === activeCategory : true;
        }
        // Case-insensitive search term
        const searchTerm = productFilters.search.toLowerCase().trim();
        // Search across multiple fields
        const matchesName = p.name.toLowerCase().includes(searchTerm);
        const matchesCategory = p.category.toLowerCase().includes(searchTerm);
        const matchesDescription = p.description?.toLowerCase().includes(searchTerm) || false;
        const matchesSearch = matchesName || matchesCategory || matchesDescription;
        // If searching, only apply category filter if there is an active category
        const matchesCategory2 = activeCategory ? p.category === activeCategory : true;
        return matchesSearch && matchesCategory2;
      })
      .sort((a, b) => a.name.localeCompare(b.name));
    totalProducts = products.length;
    // Reset to first page when filtering
    currentPage = 1;
    paginateProducts();
  }

  function paginateProducts() {
    const end = currentPage * pageSize;
    paginatedProducts = products.slice(0, end);
  }

  function handleCategoryChange(category: string) {
    activeCategory = category;
    currentPage = 1;
    
    // Set the active category icon for the starry background
    if (category && CATEGORY_CONFIG[category as keyof typeof CATEGORY_CONFIG]) {
      const categoryData = CATEGORY_CONFIG[category as keyof typeof CATEGORY_CONFIG];
      activeCategoryIcon = {
        icon: categoryData.icon,
        color: categoryData.color
      };
    } else {
      activeCategoryIcon = null;
    }
    
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
        // If page size changes, we reset pagination and need to reset the observer
        if (observer) {
            observer.disconnect();
            observer = null;
        }
        currentPage = 1;
        paginateProducts();
      }
    }, 200);
  }

  onMount(async () => {
    // Start loading immediately
    loading = true;
    
    // Initialize page size early to prevent layout shifts
    if (typeof window !== 'undefined') {
      updatePageSize();
      window.addEventListener('resize', handleResize);
    }

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
    posCheckComplete = true;

    // Load landing page data
    await loadLandingPageData();

    // Load all products once and manage them locally
    const { products: loadedProducts, error: loadError } = await loadAllProducts();
    
    if (loadError) {
      error = loadError;
    } else {
      allProducts = loadedProducts;

      // Fetch stock levels just once after products are loaded
      if (allProducts.length > 0) {
        stockLevels = await getShopStockLevels(allProducts.map(prod => prod.id));
      }
      
      // Manually trigger the first filter and pagination
      filterProducts();
    }
    
    // Complete loading only after everything is done
    loading = false;
  });

  onDestroy(() => {
    if (typeof window !== 'undefined') {
      if (resizeTimeout) {
        clearTimeout(resizeTimeout);
      }
      window.removeEventListener('resize', handleResize);
    }
    if (observer) observer.disconnect();
  });

  function toggleCart() {
    globalToggleCart();
    if (menuVisible) menuVisible = false;
  }

  function toggleMenu() {
    menuVisible = !menuVisible;
    if ($globalCartVisible) globalCartVisible.set(false);
  }

  function handleLogoClick() {
    activeCategory = '';
    activeCategoryIcon = null; // Clear floating icons when going to home
  }

  function handleShowDetails(product: Product) {
    selectedProduct = product;
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
      clearAllProductCache(); // Clear cache before reloading products
      
      // Refresh products so product card updates
      const { products: reloadedProducts } = await loadAllProducts(); 
      allProducts = reloadedProducts;
      filterProducts();

    } catch (error) {
      alert('Failed to submit review. Please try again.');
    } finally {
      submittingReview = false;
    }
  }

  afterUpdate(() => {
    // Set up IntersectionObserver for infinite scroll only when needed
    if (loadMoreTrigger && currentPage * pageSize < products.length && !observer) {
      observer = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting) {
          loadMoreProducts();
        }
      }, {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
      });
      observer.observe(loadMoreTrigger);
    } else if (observer && (currentPage * pageSize >= products.length || !loadMoreTrigger)) {
      observer.disconnect();
      observer = null;
    }
  });

  // Handle category click from landing page
  function handleLandingCategoryClick(categoryId: string) {
    if (categoryId === 'all') {
      activeCategory = undefined;
    } else {
      activeCategory = categoryId;
    }
    filterProducts(); // Ensure products are filtered by the selected category
    // Scroll to products section
    const productsSection = document.getElementById('products-section');
    if (productsSection) {
      productsSection.scrollIntoView({ behavior: 'smooth' });
    }
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

<!-- Main Content Area -->
<main class="main-content">
  
  {#if loading}
    <div class="loading-container">
      <LoadingSpinner size="60px" />
      <p>Loading...</p>
    </div>
  {:else if error}
    <div class="error-container">
      <p class="error-message">{error}</p>
      <button on:click={() => location.reload()} class="retry-btn">
        Try Again
      </button>
    </div>
  {:else if !activeCategory}
    <!-- LANDING PAGE SECTIONS -->
    
    <!-- Hero Section -->
    {#if landingHero}
      <section class="hero-section">
        <div class="hero-content">
          <div class="hero-text">
            <h1 class="neon-text-cyan hero-title">{landingHero.title}</h1>
            {#if isPosUser}
              <p class="hero-subtitle neon-text-white">Welcome POS User</p>
            {/if}
            <p class="hero-description neon-text-white">{landingHero.description}</p>
            <p class="hero-subtitle neon-text-secondary">{landingHero.subtitle}</p>
            <a href="#categories" class="btn btn-primary btn-lg hero-cta">
              {landingHero.cta_text || 'Shop Now'}
            </a>
          </div>
          <div class="hero-products">
            {#if featuredProducts.length > 0}
              <div class="hero-product-showcase">
                {#each featuredProducts.slice(0, 3) as product}
                  <div
                    class="hero-product glass-light hover-glow"
                    role="button"
                    tabindex="0"
                    on:click={() => handleShowDetails(product)}
                    on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && handleShowDetails(product)}
                    aria-label="View details for {product.name}"
                  >
                    <img src={getProductImage(product.image_url, product.category)} alt={product.name} class="hero-product-image" />
                    <h4 class="neon-text-cyan">{product.name}</h4>
                    <p class="neon-text-white">R{product.price}</p>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </div>
      </section>
    {/if}

    <!-- Categories Showcase Section -->
    {#if landingCategories}
      <section id="categories" class="categories-section">
        <div class="container">
          <div class="section-header text-center mb-5">
            <h2 class="neon-text-cyan">{landingCategories.title}</h2>
            <p class="neon-text-secondary">{landingCategories.subtitle}</p>
          </div>
          <div class="categories-grid">
            {#each landingCategories.categories as category}
              {@const backgroundImage = category.background_image || CATEGORY_BACKGROUNDS[category.id]}
              <div 
                class="category-card glass hover-glow" 
                style="--category-color: {category.color}; {backgroundImage ? `background-image: url('${backgroundImage}'); background-size: cover; background-position: center;` : ''}"
                on:click={() => handleLandingCategoryClick(category.id)}
                on:keydown={(e) => e.key === 'Enter' && handleLandingCategoryClick(category.id)}
                tabindex="0"
                role="button"
              >
                <div class="category-overlay"></div>
                <div class="category-content">
                  <div class="category-icon" style="color: {category.color};">
                    <i class="fa-solid {CATEGORY_ICONS[category.id] || 'fa-cannabis'}"></i>
                  </div>
                  <h3 class="neon-text-white">{category.name}</h3>
                  <p class="neon-text-secondary">{category.description}</p>
                </div>
              </div>
            {/each}
          </div>
        </div>
      </section>
    {/if}

    <!-- Multiple Stores Section -->
    {#if landingStores}
      <section class="stores-section">
        <div class="stores-content">
          {#if !showMap}
            <div class="stores-main-content">
              <h2 class="neon-text-cyan">{landingStores.title}</h2>
              <p class="neon-text-white">{landingStores.description}</p>
              <div class="stores-visual">
                <div class="store-fountain glass">
                  <div class="fountain-base"></div>
                  <div class="fountain-water"></div>
                  <button 
                    class="map-trigger-dot" 
                    on:click={toggleMap}
                    aria-label="View store location"
                  >
                    <i class="fa-solid fa-map-marker-alt"></i>
                  </button>
                </div>
              </div>
            </div>
          {:else}
            <div class="map-fullscreen" transition:fade={{ duration: 500 }}>
              <button 
                class="map-close-btn" 
                on:click={toggleMap}
                aria-label="Close map"
              >
                <i class="fa-solid fa-times"></i>
              </button>
              <iframe
                src={googleMapsUrl}
                width="100%"
                height="100%"
                style="border:0; border-radius: 24px;"
                allowfullscreen
                loading="lazy"
                referrerpolicy="no-referrer-when-downgrade"
              ></iframe>
            </div>
          {/if}
        </div>
      </section>
    {/if}

    <!-- Featured Products Section -->
    {#if landingFeaturedProducts && featuredProducts.length > 0}
      <section class="featured-products-section">
        <div class="container">
          <div class="section-header text-center mb-5">
            <h2 class="neon-text-cyan">{landingFeaturedProducts.title}</h2>
            <p class="neon-text-secondary">{landingFeaturedProducts.subtitle}</p>
          </div>
          <div class="featured-products-grid">
            {#each featuredProducts.slice(0, 4) as product}
              <ProductCard 
                {product}
                stock={stockLevels[product.id] ?? 0}
                on:showDetails={e => handleShowDetails(e.detail.product)}
                on:showReview={openReviewModal}
              />
            {/each}
          </div>
        </div>
      </section>
    {/if}

    <!-- Customer Testimonials Section -->
    {#if landingTestimonials && landingTestimonials.testimonials?.length > 0}
      <section class="testimonials-section">
        <div class="container">
          <div class="section-header text-center mb-5">
            <h2 class="neon-text-cyan">{landingTestimonials.title}</h2>
          </div>
          <div class="testimonials-grid">
            {#each landingTestimonials.testimonials as testimonial}
              <div class="testimonial-card glass hover-glow">
                <div class="testimonial-rating">
                  {#each Array(5) as _, i}
                    <i class="fa-solid fa-star {i < testimonial.rating ? 'text-yellow-400' : 'text-gray-400'}"></i>
                  {/each}
                </div>
                <p class="neon-text-white testimonial-comment">"{testimonial.comment}"</p>
                <div class="testimonial-author">
                  <span class="neon-text-cyan">{testimonial.name}</span>
                  {#if testimonial.verified}
                    <span class="verified-badge">✓</span>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        </div>
      </section>
    {/if}

    <Footer />
  {:else}
    <!-- PRODUCTS SECTION -->
    <section id="products-section" class="products-section">
      <div class="category-header">
        {#if productFilters.search}
          <i class="fa-solid fa-magnifying-glass category-header-icon"></i>
        {:else if activeCategory && CATEGORY_ICONS[activeCategory]}
          <i class="fa-solid {CATEGORY_ICONS[activeCategory]} category-header-icon"></i>
        {/if}
        <input
          type="text"
          class="search-bar"
          placeholder="Search products..."
          bind:value={productFilters.search}
          on:input={debounce(filterProducts, 300)}
          aria-label="Search products"
          autocomplete="off"
        />
      </div>
      <div class="category-section">
        <div class="products-grid">
          {#if paginatedProducts.length === 0}
            <div class="no-results-in-grid">
              <p>No products found matching "{productFilters.search}"</p>
              <p class="sub-text">Try a different search or clear your search above.</p>
            </div>
          {:else}
          {#each paginatedProducts as product (product.id)}
            <div in:fly={{ y: 30, duration: 350 }}>
              <ProductCard 
                {product}
                stock={stockLevels[product.id] ?? 0}
                on:showDetails={e => handleShowDetails(e.detail.product)}
                on:showReview={openReviewModal}
              />
            </div>
          {/each}
          <!-- Infinite scroll trigger -->
          {#if currentPage * pageSize < products.length}
            <div bind:this={loadMoreTrigger} class="load-more-trigger"></div>
            {/if}
          {/if}
        </div>
      </div>
    </section>
  {/if}
</main>

<!-- Cart Sidebar Component -->
{#if $globalCartVisible}
  <div class="cart-overlay" role="button" tabindex="0" aria-label="Close cart sidebar" on:click={() => globalCartVisible.set(false)} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { globalCartVisible.set(false); } }} style="position: fixed; inset: 0; z-index: 1999; background: transparent;"></div>
{/if}
<CartSidebar visible={$globalCartVisible} toggleVisibility={toggleCart} isPosUser={isPosUser} />

<!-- Side Menu Component -->
<SideMenu 
  visible={menuVisible} 
  toggleVisibility={toggleMenu}
  on:selectcategory={e => activeCategory = e.detail.id}
/>

{#if selectedProduct}
  <ProductDetailsModal 
    product={selectedProduct} 
    show={true} 
    stock={stockLevels[selectedProduct.id] ?? 0}
    on:close={closeProductModal}
    on:addToCart={e => {
      cartStore.addItem({ ...e.detail.product, quantity: e.detail.quantity });
      globalCartVisible.set(true);
    }}
  />
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
  .main-content {
    max-width: 1920px;
    margin: 0 auto;
   
  }

  /* Hero Section */
  .hero-section {
    min-height: 80vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    position: relative;
    overflow: hidden;
  }

  .hero-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4rem;
    max-width: 1200px;
    width: 100%;
    align-items: center;
  }

  .hero-text {
    text-align: left;
  }

  .hero-title {
    font-size: 4rem;
    font-weight: 900;
    margin-bottom: 1rem;
    letter-spacing: 2px;
    text-transform: uppercase;
  }

  .hero-subtitle {
    font-size: 1.5rem;
    margin-bottom: 1rem;
    font-weight: 600;
  }

  .hero-description {
    font-size: 2rem;
    margin-bottom: 1rem;
    font-weight: 700;
  }

  .hero-cta {
    margin-top: 2rem;
    padding: 1rem 2rem;
    font-size: 1.2rem;
    font-weight: 600;
    text-decoration: none;
  }

  .hero-product-showcase {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 1.5rem;
  }

  .hero-product {
    
    text-align: center;
    border-radius: 12px;
    cursor: pointer;
    transition: var(--transition-smooth);
  }

  .hero-product-image {
    width: 100%;
    height: 120px;
    object-fit: cover;
    border-radius: 8px;
    margin-bottom: 1rem;
  }

  /* Categories Section */
  .categories-section {
    padding: 6rem 2rem;
    background: var(--bg-glass);
  }

  .container {
    max-width: 1200px;
    margin: 0 auto;
  }

  .section-header {
    margin-bottom: 3rem;
  }

  .section-header h2 {
    font-size: 2.5rem;
    font-weight: 700;
    margin-bottom: 1rem;
  }

  .categories-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 1.5rem;
  }

  .category-card {
    padding: 2rem 1.5rem;
    text-align: center;
    border-radius: 12px;
    cursor: pointer;
    transition: var(--transition-smooth);
    border: 2px solid transparent;
    position: relative;
    overflow: hidden;
    min-height: 200px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .category-card:hover {
    border-color: var(--category-color);
    box-shadow: 0 0 30px var(--category-color), 0 0 60px rgba(255, 255, 255, 0.1);
    transform: translateY(-5px);
  }

  .category-card:hover .category-overlay {
    background: rgba(0, 0, 0, 0.2);
    box-shadow: inset 0 0 50px var(--category-color);
  }

  .category-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    transition: all 0.3s ease;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .category-content {
    position: relative;
    z-index: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: 0.75rem;
  }

  .category-icon {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    opacity: 1;
    text-shadow: 
      0 0 10px currentColor,
      0 0 20px currentColor,
      0 4px 8px rgba(0, 0, 0, 0.8);
    filter: drop-shadow(0 0 15px currentColor);
    transition: all 0.3s ease;
  }

  .category-card:hover .category-icon {
    transform: scale(1.1);
    text-shadow: 
      0 0 15px currentColor,
      0 0 30px currentColor,
      0 4px 8px rgba(0, 0, 0, 0.8);
  }

  .category-card h3 {
    font-size: 1.3rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
    text-shadow: 
      0 0 10px rgba(255, 255, 255, 0.8),
      0 2px 4px rgba(0, 0, 0, 0.9);
    color: white !important;
  }

  .category-card p {
    text-shadow: 
      0 0 8px rgba(255, 255, 255, 0.6),
      0 2px 4px rgba(0, 0, 0, 0.9);
    color: rgba(255, 255, 255, 0.9) !important;
  }

  /* Stores Section */
  .stores-section {
    
 
    min-height: 400px;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }

  .stores-content {
    width: 100%;
    max-width: 1200px;
    min-height: 400px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    position: relative;
  }

  .stores-main-content {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }

  .stores-visual {
    position: relative;
    width: 100%;
    max-width: 600px;
    height: 220px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .store-fountain {
    width: 200px;
    height: 200px;
    border-radius: 50%;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    margin: 0 auto;
  }

  .fountain-base {
    width: 80%;
    height: 80%;
    border-radius: 50%;
    background: var(--gradient-primary);
    opacity: 0.7;
  }

  .fountain-water {
    position: absolute;
    width: 60%;
    height: 60%;
    border-radius: 50%;
    background: var(--neon-cyan);
    opacity: 0.3;
    animation: fountain-pulse 2s ease-in-out infinite;
  }

  @keyframes fountain-pulse {
    0%, 100% { transform: scale(1); opacity: 0.3; }
    50% { transform: scale(1.2); opacity: 0.6; }
  }

  .map-trigger-dot {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: var(--neon-cyan);
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    color: var(--bg-primary);
    box-shadow: 
      0 0 20px var(--neon-cyan),
      0 0 40px var(--neon-cyan);
    animation: pulse-dot 2s ease-in-out infinite;
    transition: var(--transition-fast);
    z-index: 5;
  }

  .map-trigger-dot:hover {
    transform: translate(-50%, -50%) scale(1.1);
    box-shadow: 
      0 0 30px var(--neon-cyan),
      0 0 60px var(--neon-cyan);
  }

  @keyframes pulse-dot {
    0%, 100% { 
      box-shadow: 
        0 0 20px var(--neon-cyan),
        0 0 40px var(--neon-cyan);
    }
    50% { 
      box-shadow: 
        0 0 30px var(--neon-cyan),
        0 0 60px var(--neon-cyan),
        0 0 80px var(--neon-cyan);
    }
  }

  .map-close-btn {
    position: absolute;
    top: 20px;
    right: 20px;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: var(--bg-glass);
    border: 2px solid var(--neon-cyan);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.2rem;
    color: var(--neon-cyan);
    z-index: 20;
    transition: var(--transition-fast);
    backdrop-filter: blur(10px);
  }

  .map-close-btn:hover {
    background: var(--neon-cyan);
    color: var(--bg-primary);
    transform: scale(1.1);
    box-shadow: var(--shadow-neon-cyan);
  }

  .map-trigger-dot {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: var(--neon-cyan);
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    color: var(--bg-primary);
    box-shadow: 
      0 0 20px var(--neon-cyan),
      0 0 40px var(--neon-cyan);
    animation: pulse-dot 2s ease-in-out infinite;
    transition: var(--transition-fast);
    z-index: 5;
  }

  .map-trigger-dot:hover {
    transform: translate(-50%, -50%) scale(1.1);
    box-shadow: 
      0 0 30px var(--neon-cyan),
      0 0 60px var(--neon-cyan);
  }

  @keyframes pulse-dot {
    0%, 100% { 
      box-shadow: 
        0 0 20px var(--neon-cyan),
        0 0 40px var(--neon-cyan);
    }
    50% { 
      box-shadow: 
        0 0 30px var(--neon-cyan),
        0 0 60px var(--neon-cyan),
        0 0 80px var(--neon-cyan);
    }
  }

  .map-close-btn {
    position: absolute;
    top: 20px;
    right: 20px;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: var(--bg-glass);
    border: 2px solid var(--neon-cyan);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.2rem;
    color: var(--neon-cyan);
    z-index: 20;
    transition: var(--transition-fast);
    backdrop-filter: blur(10px);
  }

  .map-close-btn:hover {
    background: var(--neon-cyan);
    color: var(--bg-primary);
    transform: scale(1.1);
    box-shadow: var(--shadow-neon-cyan);
  }

  .map-fullscreen {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    width: 100%;
    height: 100%;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-secondary);
    border-radius: 24px;
    overflow: hidden;
  }

  .map-fullscreen iframe {
    width: 100%;
    height: 100%;
    min-height: 350px;
    border-radius: 24px;
  }

  /* Featured Products Section */
  .featured-products-section {
    padding: 6rem 2rem;
  }

  .featured-products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 2rem;
  }

  /* Testimonials Section */
  .testimonials-section {
    padding: 6rem 2rem;
    background: var(--bg-glass);
  }

  .testimonials-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 2rem;
  }

  .testimonial-card {
    padding: 2rem;
    border-radius: 12px;
    transition: var(--transition-smooth);
  }

  .testimonial-rating {
    margin-bottom: 1rem;
  }

  .testimonial-comment {
    font-size: 1.1rem;
    line-height: 1.6;
    margin-bottom: 1.5rem;
    font-style: italic;
  }

  .testimonial-author {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 600;
  }

  .verified-badge {
    background: var(--neon-green);
    color: var(--bg-primary);
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8rem;
    font-weight: bold;
  }

  /* Products Section */
  .products-section {
    padding: 1rem;
  }

  .category-header {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    padding: 0.5rem 0;
    margin-bottom: 2rem;
  }

  .search-bar {
    padding: 1rem 1.5rem;
    border: 2px solid var(--border-primary);
    border-radius: 25px;
    background: var(--bg-glass);
    color: var(--text-primary);
    font-size: 1rem;
    max-width: 400px;
    width: 100%;
    backdrop-filter: blur(10px);
    transition: var(--transition-fast);
  }

  .search-bar:focus {
    outline: none;
    border-color: var(--neon-cyan);
    box-shadow: var(--shadow-neon-cyan);
  }

  .products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 2rem;
    padding-bottom: 2rem;
    align-items: start;
    justify-items: normal;
  }

  .loading-container,
  .error-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 60vh;
    text-align: center;
    padding: 2rem;
  }

  .error-message {
    color: #f87171;
    background: var(--bg-glass);
    padding: 1.5rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    font-size: 1.1rem;
    max-width: 600px;
  }

  .retry-btn {
    background: var(--gradient-primary);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1.1rem;
    transition: var(--transition-fast);
  }

  .retry-btn:hover {
    box-shadow: var(--shadow-neon-cyan);
  }

  .text-yellow-400 {
    color: #facc15;
  }

  .text-gray-400 {
    color: #9ca3af;
  }

  .text-center {
    text-align: center;
  }

  .mb-5 {
    margin-bottom: 3rem;
  }

  /* Responsive Design */
  @media (max-width: 1024px) {
    .hero-content {
      grid-template-columns: 1fr;
      gap: 2rem;
      text-align: center;
    }

    .hero-title {
      font-size: 3rem;
    }

    .categories-grid {
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    }
  }

  @media (max-width: 768px) {
    .hero-section {
      padding: 2rem 1rem;
    }

    .hero-title {
      font-size: 2.5rem;
    }

    .hero-description {
      font-size: 1.5rem;
    }

    .categories-section,
    .stores-section,
    .featured-products-section,
    .testimonials-section {
      padding: 3rem 1rem;
    }

    .section-header h2 {
      font-size: 2rem;
    }

    .categories-grid {
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 1rem;
    }
    
    .featured-products-grid,
    .testimonials-grid {
      grid-template-columns: 1fr;
    }

    .products-grid {
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1.5rem;
    }
  }

  @media (max-width: 480px) {
    .hero-title {
      font-size: 2rem;
    }

    .hero-description {
      font-size: 1.2rem;
    }

    .products-grid {
      grid-template-columns: 1fr;
      gap: 1rem;
      padding: 0 0.5rem 2rem 0.5rem;
    }
  }

  .map-container {
    width: 100%;
    max-width: 600px;
    margin: 0 auto;
    box-shadow: 0 0 30px var(--neon-cyan);
    border-radius: 12px;
    overflow: hidden;
  }
</style>

