<script lang="ts">
  import { onMount } from 'svelte';
  import { cartStore } from '$lib/stores/cartStore';
  import { fetchProducts } from '$lib/services/productService';
  import { supabase } from '$lib/supabase';
  import type { Product } from '$lib/types';
  
  import Navbar from '$lib/components/Navbar.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import ProductCard from '$lib/components/ProductCard.svelte';
  import CartSidebar from '$lib/components/CartSidebar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';

  let products: Product[] = [];
  let filteredProducts: Product[] = [];
  let cartVisible = false;
  let menuVisible = false;
  let loading = true;
  let error: string | null = null;
  let cartButton: HTMLButtonElement;
  let activeCategory: string | undefined = undefined;
  let logoUrl = '';

  const categoryNames: Record<string, string> = {
    'flower': 'Flower',
    'concentrate': 'Concentrate',
    'joints': 'Joints',
    'edibles': 'Edibles'
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
  });

  $: if (activeCategory) {
    filteredProducts = products.filter(product => product.category === activeCategory);
    } else {
    filteredProducts = [];
    }

  function addToCart(product: Product) {
    cartButton.classList.add('cart-animate');
    cartStore.addItem(product);

setTimeout(() => {
  cartButton.classList.remove('cart-animate');
    }, 500);
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
</script>

<!-- Navbar Component -->
<Navbar 
  bind:cartButton
  onCartToggle={toggleCart} 
  onMenuToggle={toggleMenu}
  onLogoClick={handleLogoClick}
/>

<!-- Category Navigation -->
<CategoryNav bind:activeCategory />

<!-- Watermark -->


<!-- Main Content Area -->
<main class="products-container">
  <div class="watermark" style="--logo-url: url('{logoUrl}')"></div>
  {#if loading}
    <div class="loading-container">
      <LoadingSpinner size="60px" />
      <p>Loading products...</p>
    </div>
  {:else if error}
    <div class="error-container">
      <p class="error-message">{error}</p>
      <button on:click={() => window.location.reload()} class="retry-btn">
        Try Again
      </button>
    </div>
  {:else if !activeCategory}
    <div class="welcome-section">
      <h1>Welcome to Route 420</h1>
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
    
    <h2 class="category-title">{categoryNames[activeCategory]}</h2>
    <div class="products-grid">
      {#each filteredProducts as product (product.id)}
        <ProductCard {product} onAddToCart={addToCart} />
      {/each}
    </div>
  {/if}
</main>

<!-- Cart Sidebar Component -->
<CartSidebar visible={cartVisible} toggleVisibility={toggleCart} />

<!-- Side Menu Component -->
<SideMenu visible={menuVisible} toggleVisibility={toggleMenu} />

<style>
  .products-container {
    margin-top: 200px;
    padding: 2rem;
    min-height: calc(100vh - 200px);
    max-width: 1920px;
    margin-left: auto;
    margin-right: auto;
    position: relative;
    z-index: 1;
  }

  .welcome-section {
    max-width: 800px;
    margin: 0 auto;
    text-align: center;
    padding: 2rem;
    background: white;
    border-radius: 16px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
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
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 2rem;
    padding: 1rem;
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
      margin-top: 220px;
      min-height: calc(100vh - 220px);
    padding: 1.5rem;
    }
    
    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 1.75rem;
    }
  }
  
  @media (max-width: 1200px) {
    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
      gap: 1.5rem;
    }
  }
  
  @media (max-width: 768px) {
    .products-container {
      margin-top: 240px;
      min-height: calc(100vh - 240px);
      padding: 1rem;
  }

    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 1rem;
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
      margin-top: 260px;
      min-height: calc(100vh - 260px);
      padding: 0.5rem;
  }

    .welcome-section {
      padding: 1rem;
      margin: 0 0.5rem;
  }
  }

  :global(.category-nav) {
    position: fixed;
    top: 60px;
    left: 0;
    right: 0;
    z-index: 10;
    background-color: #f8f9fa;
  }

  .watermark {
    position: fixed;
    top: 200px;
    left: 0;
    right: 0;
    bottom: 0;
    background-image: var(--logo-url);
    background-repeat: no-repeat;
    background-position: center;
    background-size: 50%;
    opacity: 0.1;
    z-index: 0;
    pointer-events: none;
  }

  :global(body) {
    margin: 0;
    padding: 0;
    overflow-x: hidden;
  }

  :global(*) {
    position: relative;
    z-index: 1;
  }
</style>
