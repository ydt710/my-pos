<script lang="ts">
  import { onMount } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  import { cartStore } from '$lib/stores/cartStore';
  import { fetchProducts } from '$lib/services/productService';
  import { supabase } from '$lib/supabase';
  import type { Product } from '$lib/types';
  
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import ProductCard from '$lib/components/ProductCard.svelte';
  import CartSidebar from '$lib/components/CartSidebar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';
  import ProductDetailsModal from '$lib/components/ProductDetailsModal.svelte';

  let products: Product[] = [];
  let filteredProducts: Product[] = [];
  let cartVisible = false;
  let menuVisible = false;
  let loading = true;
  let error: string | null = null;
  let activeCategory: string | undefined = undefined;
  let logoUrl = '';
  let isPosUser = false;
  let selectedProduct: Product | null = null;

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

  onMount(async () => {
    loading = true;
    const result = await fetchProducts();
    products = result.products;
    error = result.error;
    loading = false;

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

    Object.values(categoryBackgrounds).forEach(url => {
      const img = new window.Image();
      img.src = url;
    });
  });

  $: if (activeCategory) {
    filteredProducts = products.filter(product => product.category === activeCategory);
    } else {
    filteredProducts = [];
    }

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

<!-- Category Navigation -->
<CategoryNav 
  bind:activeCategory 
  backgroundUrl={categoryBackgrounds[activeCategory || 'home']} 
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
  {#key activeCategory}
    {#if loading}
      <div class="loading-container" transition:fade>
        <LoadingSpinner size="60px" />
        <p>Loading products...</p>
      </div>
    {:else if error}
      <div class="error-container" transition:fade>
        <p class="error-message">{error}</p>
        <button on:click={fetchProducts} class="retry-btn">
          Try Again
        </button>
      </div>
    {:else if !activeCategory}
      <div class="welcome-section" transition:fade>
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
      <div class="empty-container" transition:fade>
        <p>No products available in this category at this time.</p>
      </div>
    {:else}
      <div class="category-section" transition:fade>
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
      </div>
    {/if}
  {/key}
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
    background: none;
    border-radius: 16px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    position: relative;
    overflow: hidden;
    color: #fff;
  }

  .welcome-section .welcome-overlay {
    content: "";
    position: absolute;
    inset: 0;
    background: rgba(0,0,0,0.7);
    z-index: 0;
    pointer-events: none;
  }

  .welcome-section > *:not(.welcome-overlay) {
    position: relative;
    z-index: 1;
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
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 2rem;
    padding: 1rem;
  }

  @media (max-width: 600px) {
    .products-grid {
      grid-template-columns: repeat(2, 1fr);
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
    background: white;
    box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  }

  /* Category section with background image and overlay */
  .category-section {
    position: relative;
    padding: 2rem 0;
    border-radius: 16px;
    overflow: hidden;
  }
  .category-section::before {
    content: "";
    position: absolute;
    inset: 0;
    background: rgb(0 8 2 / 70%); /* adjust for desired overlay */
    z-index: 0;
    pointer-events: none;
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
</style>
