<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { getProductImage } from '$lib/constants';
  import { fade } from 'svelte/transition';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import type { Product } from '$lib/types/index';
  import { CATEGORY_BACKGROUNDS } from '$lib/constants';

  interface LandingHero {
    id: number;
    title: string;
    subtitle: string;
    description: string;
    background_image_url?: string;
    featured_products: string[];
    cta_text: string;
    cta_link: string;
  }

  interface LandingCategories {
    id: number;
    title: string;
    subtitle: string;
    categories: Array<{
      id: string;
      name: string;
      description: string;
      color: string;
      background_image?: string;
    }>;
  }

  interface LandingStores {
    id: number;
    title: string;
    description: string;
    background_image_url?: string;
  }

  interface LandingFeaturedProducts {
    id: number;
    title: string;
    subtitle: string;
    product_ids: string[];
  }

  interface LandingTestimonials {
    id: number;
    title: string;
    testimonials: Array<{
      name: string;
      rating: number;
      comment: string;
      verified: boolean;
    }>;
  }

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let success: string | null = null;
  let activeSection = 'hero';

  // Data for each section
  let heroData: LandingHero | null = null;
  let categoriesData: LandingCategories | null = null;
  let storesData: LandingStores | null = null;
  let featuredProductsData: LandingFeaturedProducts | null = null;
  let testimonialsData: LandingTestimonials | null = null;

  // Available products for selection
  let allProducts: Product[] = [];

  // Temporary form data
  let newTestimonial = { name: '', rating: 5, comment: '', verified: true };
  let newCategory = { id: '', name: '', description: '', color: '#00f0ff', background_image: '' };

  // Default category background images (matching CategoryNav)
  const defaultCategoryBackgrounds = CATEGORY_BACKGROUNDS;

  const predefinedColors = [
    '#00f0ff', '#ff6a00', '#43e97b', '#b993d6', '#fcdd43', '#ff00de',
    '#39ff14', '#0066ff', '#ee0979', '#8ca6db'
  ];

  onMount(async () => {
    await loadData();
  });

  async function loadData() {
    loading = true;
    error = null;
    try {
      // Load hero data
      const { data: hero } = await supabase
        .from('landing_hero')
        .select('*')
        .limit(1)
        .maybeSingle();
      heroData = hero;

      // Load categories data
      const { data: categories } = await supabase
        .from('landing_categories')
        .select('*')
        .limit(1)
        .maybeSingle();
      categoriesData = categories;
      
      // Ensure background_image property exists for all categories
      if (categoriesData?.categories) {
        categoriesData.categories = categoriesData.categories.map(cat => ({
          ...cat,
          background_image: cat.background_image || defaultCategoryBackgrounds[cat.id] || ''
        }));
      }

      // Load stores data
      const { data: stores } = await supabase
        .from('landing_stores')
        .select('*')
        .limit(1)
        .maybeSingle();
      storesData = stores;

      // Load featured products data
      const { data: featured } = await supabase
        .from('landing_featured_products')
        .select('*')
        .limit(1)
        .maybeSingle();
      featuredProductsData = featured;

      // Load testimonials data
      const { data: testimonials } = await supabase
        .from('landing_testimonials')
        .select('*')
        .limit(1)
        .maybeSingle();
      testimonialsData = testimonials;

      // Load all products for selection
      const { data: products } = await supabase
        .from('products')
        .select('id, name, price, image_url, category, description')
        .order('name');
      allProducts = products || [];

    } catch (err: any) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function saveSection(section: string) {
    saving = true;
    error = null;
    success = null;
    try {
      switch (section) {
        case 'hero':
          if (heroData) {
            await supabase
              .from('landing_hero')
              .upsert(heroData);
          }
          break;
        case 'categories':
          if (categoriesData) {
            await supabase
              .from('landing_categories')
              .upsert(categoriesData);
          }
          break;
        case 'stores':
          if (storesData) {
            await supabase
              .from('landing_stores')
              .upsert(storesData);
          }
          break;
        case 'featured':
          if (featuredProductsData) {
            await supabase
              .from('landing_featured_products')
              .upsert(featuredProductsData);
          }
          break;
        case 'testimonials':
          if (testimonialsData) {
            await supabase
              .from('landing_testimonials')
              .upsert(testimonialsData);
          }
          break;
      }
      success = `${section.charAt(0).toUpperCase() + section.slice(1)} section saved successfully!`;
      setTimeout(() => success = null, 3000);
    } catch (err: any) {
      error = err.message;
    } finally {
      saving = false;
    }
  }

  function addTestimonial() {
    if (!newTestimonial.name || !newTestimonial.comment) return;
    if (!testimonialsData) return;
    
    testimonialsData.testimonials = [...testimonialsData.testimonials, { ...newTestimonial }];
    newTestimonial = { name: '', rating: 5, comment: '', verified: true };
  }

  function removeTestimonial(index: number) {
    if (!testimonialsData) return;
    testimonialsData.testimonials = testimonialsData.testimonials.filter((_, i) => i !== index);
  }

  function addCategory() {
    if (!newCategory.id || !newCategory.name) return;
    if (!categoriesData) return;
    
    // Set default background image if one wasn't provided
    if (!newCategory.background_image && defaultCategoryBackgrounds[newCategory.id]) {
      newCategory.background_image = defaultCategoryBackgrounds[newCategory.id];
    }
    
    categoriesData.categories = [...categoriesData.categories, { ...newCategory }];
    newCategory = { id: '', name: '', description: '', color: '#00f0ff', background_image: '' };
  }

  function removeCategory(index: number) {
    if (!categoriesData) return;
    categoriesData.categories = categoriesData.categories.filter((_, i) => i !== index);
  }

  function toggleProductSelection(productId: string, section: 'hero' | 'featured') {
    if (section === 'hero' && heroData) {
      const index = heroData.featured_products.indexOf(productId);
      if (index === -1) {
        heroData.featured_products = [...heroData.featured_products, productId];
      } else {
        heroData.featured_products = heroData.featured_products.filter(id => id !== productId);
      }
    } else if (section === 'featured' && featuredProductsData) {
      const index = featuredProductsData.product_ids.indexOf(productId);
      if (index === -1) {
        featuredProductsData.product_ids = [...featuredProductsData.product_ids, productId];
      } else {
        featuredProductsData.product_ids = featuredProductsData.product_ids.filter(id => id !== productId);
      }
    }
  }
</script>

<StarryBackground />

<main class="admin-main">
  <div class="admin-container">
    <div class="admin-header">
      <h1 class="neon-text-cyan">Landing Page Management</h1>
    </div>

    {#if error}
      <div class="alert alert-danger" transition:fade>{error}</div>
    {/if}

    {#if success}
      <div class="alert alert-success" transition:fade>{success}</div>
    {/if}

    {#if loading}
      <div class="text-center">
        <div class="spinner-large"></div>
        <p class="neon-text-cyan mt-2">Loading landing page data...</p>
      </div>
    {:else}
      <!-- Section Navigation -->
      <div class="section-nav glass mb-4">
        <div class="nav-buttons">
          <button class="btn {activeSection === 'hero' ? 'btn-primary' : 'btn-secondary'}" on:click={() => activeSection = 'hero'}>Hero Section</button>
          <button class="btn {activeSection === 'categories' ? 'btn-primary' : 'btn-secondary'}" on:click={() => activeSection = 'categories'}>Categories</button>
          <button class="btn {activeSection === 'stores' ? 'btn-primary' : 'btn-secondary'}" on:click={() => activeSection = 'stores'}>Stores</button>
          <button class="btn {activeSection === 'featured' ? 'btn-primary' : 'btn-secondary'}" on:click={() => activeSection = 'featured'}>Featured Products</button>
          <button class="btn {activeSection === 'testimonials' ? 'btn-primary' : 'btn-secondary'}" on:click={() => activeSection = 'testimonials'}>Testimonials</button>
        </div>
      </div>

      <!-- Hero Section -->
      {#if activeSection === 'hero' && heroData}
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Hero Section</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-2 gap-3">
              <div class="form-group">
                <label for="hero-title" class="form-label">Title</label>
                <input id="hero-title" type="text" bind:value={heroData.title} class="form-control" />
              </div>
              
              <div class="form-group">
                <label for="hero-cta" class="form-label">CTA Text</label>
                <input id="hero-cta" type="text" bind:value={heroData.cta_text} class="form-control" />
              </div>
              
              <div class="form-group">
                <label for="hero-description" class="form-label">Description</label>
                <input id="hero-description" type="text" bind:value={heroData.description} class="form-control" />
              </div>
              
              <div class="form-group">
                <label for="hero-cta-link" class="form-label">CTA Link</label>
                <input id="hero-cta-link" type="text" bind:value={heroData.cta_link} class="form-control" />
              </div>
            </div>
            
            <div class="form-group">
              <label for="hero-subtitle" class="form-label">Subtitle</label>
              <textarea id="hero-subtitle" bind:value={heroData.subtitle} rows="2" class="form-control"></textarea>
            </div>

            <!-- Featured Products Selection -->
            <div class="form-group">
              <label class="form-label">Featured Products (max 3 for hero display)</label>
              <div class="product-grid">
                {#each allProducts as product}
                  <div class="product-selector glass-light {heroData.featured_products.includes(product.id) ? 'selected' : ''}" 
                       on:click={() => toggleProductSelection(product.id, 'hero')}
                       on:keydown={(e) => e.key === 'Enter' && toggleProductSelection(product.id, 'hero')}
                       tabindex="0"
                       role="button">
                    <img src={getProductImage(product.image_url, product.category)} alt={product.name} class="product-image" />
                    <div class="product-info">
                      <h4 class="neon-text-white">{product.name}</h4>
                      <p class="neon-text-cyan">R{product.price}</p>
                    </div>
                    {#if heroData.featured_products.includes(product.id)}
                      <div class="selected-indicator">✓</div>
                    {/if}
                  </div>
                {/each}
              </div>
            </div>

            <button class="btn btn-primary" on:click={() => saveSection('hero')} disabled={saving}>
              {saving ? 'Saving...' : 'Save Hero Section'}
            </button>
          </div>
        </div>
      {/if}

      <!-- Categories Section -->
      {#if activeSection === 'categories' && categoriesData}
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Categories Section</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-2 gap-3 mb-4">
              <div class="form-group">
                <label for="cat-title" class="form-label">Title</label>
                <input id="cat-title" type="text" bind:value={categoriesData.title} class="form-control" />
              </div>
              
              <div class="form-group">
                <label for="cat-subtitle" class="form-label">Subtitle</label>
                <input id="cat-subtitle" type="text" bind:value={categoriesData.subtitle} class="form-control" />
              </div>
            </div>

            <!-- Add New Category -->
            <div class="glass-light p-3 mb-4">
              <h3 class="neon-text-cyan mb-3">Add New Category</h3>
              <div class="grid grid-3 gap-2 mb-3">
                <div class="form-group">
                  <label for="new-cat-id" class="form-label">Category ID</label>
                  <input id="new-cat-id" type="text" bind:value={newCategory.id} placeholder="e.g., flower" class="form-control" />
                </div>
                
                <div class="form-group">
                  <label for="new-cat-name" class="form-label">Name</label>
                  <input id="new-cat-name" type="text" bind:value={newCategory.name} placeholder="e.g., Sales" class="form-control" />
                </div>
                
                <div class="form-group">
                  <label for="new-cat-color" class="form-label">Color</label>
                  <select id="new-cat-color" bind:value={newCategory.color} class="form-control form-select">
                    {#each predefinedColors as color}
                      <option value={color} style="color: {color};">{color}</option>
                    {/each}
                  </select>
                </div>
              </div>
              
              <div class="grid grid-2 gap-2 mb-3">
                <div class="form-group">
                  <label for="new-cat-desc" class="form-label">Description</label>
                  <input id="new-cat-desc" type="text" bind:value={newCategory.description} placeholder="e.g., Premium products" class="form-control" />
                </div>
                
                <div class="form-group">
                  <label for="new-cat-bg" class="form-label">Background Image URL</label>
                  <input id="new-cat-bg" type="url" bind:value={newCategory.background_image} placeholder="https://..." class="form-control" />
                </div>
              </div>
              
              {#if newCategory.background_image}
                <div class="form-group mb-3">
                  <label class="form-label">Preview</label>
                  <div class="category-preview" style="background-image: url('{newCategory.background_image}');">
                    <div class="category-overlay"></div>
                    <div class="category-content">
                      <div class="category-icon" style="color: {newCategory.color};">
                        <i class="fa-solid fa-cannabis"></i>
                      </div>
                      <h4 class="neon-text-white">{newCategory.name || 'Category Name'}</h4>
                      <p class="neon-text-secondary">{newCategory.description || 'Description'}</p>
                    </div>
                  </div>
                </div>
              {/if}
              
              <button class="btn btn-secondary" on:click={addCategory}>Add Category</button>
            </div>

            <!-- Existing Categories -->
            <div class="categories-list">
              <h3 class="neon-text-cyan mb-3">Current Categories</h3>
              {#each categoriesData.categories as category, index}
                <div class="category-item glass-light p-3 mb-2">
                  <div class="grid grid-3 gap-2 mb-3">
                    <div class="form-group">
                      <label class="form-label">Category ID</label>
                      <input type="text" bind:value={category.id} class="form-control" />
                    </div>
                    
                    <div class="form-group">
                      <label class="form-label">Name</label>
                      <input type="text" bind:value={category.name} class="form-control" />
                    </div>
                    
                    <div class="form-group">
                      <label class="form-label">Color</label>
                      <div class="flex gap-2 align-center">
                        <select bind:value={category.color} class="form-control form-select">
                          {#each predefinedColors as color}
                            <option value={color} style="color: {color};">{color}</option>
                          {/each}
                        </select>
                        <div class="color-preview" style="background-color: {category.color};"></div>
                      </div>
                    </div>
                  </div>
                  
                  <div class="grid grid-2 gap-2 mb-3">
                    <div class="form-group">
                      <label class="form-label">Description</label>
                      <input type="text" bind:value={category.description} class="form-control" />
                    </div>
                    
                    <div class="form-group">
                      <label class="form-label">Background Image URL</label>
                      <input type="url" bind:value={category.background_image} placeholder="https://..." class="form-control" />
                    </div>
                  </div>
                  
                  {#if category.background_image}
                    <div class="form-group mb-3">
                      <label class="form-label">Preview</label>
                      <div class="category-preview" style="background-image: url('{category.background_image}');">
                        <div class="category-overlay"></div>
                        <div class="category-content">
                          <div class="category-icon" style="color: {category.color};">
                            <i class="fa-solid fa-cannabis"></i>
                          </div>
                          <h4 class="neon-text-white">{category.name}</h4>
                          <p class="neon-text-secondary">{category.description}</p>
                        </div>
                      </div>
                    </div>
                  {/if}
                  
                  <div class="flex gap-2 align-center">
                    <button class="btn btn-danger btn-sm" on:click={() => removeCategory(index)}>Remove Category</button>
                    {#if defaultCategoryBackgrounds[category.id] && category.background_image !== defaultCategoryBackgrounds[category.id]}
                      <button class="btn btn-secondary btn-sm" on:click={() => category.background_image = defaultCategoryBackgrounds[category.id]}>
                        Use Default Image
                      </button>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>

            <button class="btn btn-primary" on:click={() => saveSection('categories')} disabled={saving}>
              {saving ? 'Saving...' : 'Save Categories Section'}
            </button>
          </div>
        </div>
      {/if}

      <!-- Stores Section -->
      {#if activeSection === 'stores' && storesData}
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Stores Section</h2>
          </div>
          <div class="card-body">
            <div class="form-group">
              <label for="stores-title" class="form-label">Title</label>
              <input id="stores-title" type="text" bind:value={storesData.title} class="form-control" />
            </div>
            
            <div class="form-group">
              <label for="stores-desc" class="form-label">Description</label>
              <textarea id="stores-desc" bind:value={storesData.description} rows="3" class="form-control"></textarea>
            </div>

            <button class="btn btn-primary" on:click={() => saveSection('stores')} disabled={saving}>
              {saving ? 'Saving...' : 'Save Stores Section'}
            </button>
          </div>
        </div>
      {/if}

      <!-- Featured Products Section -->
      {#if activeSection === 'featured' && featuredProductsData}
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Featured Products Section</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-2 gap-3 mb-4">
              <div class="form-group">
                <label for="featured-title" class="form-label">Title</label>
                <input id="featured-title" type="text" bind:value={featuredProductsData.title} class="form-control" />
              </div>
              
              <div class="form-group">
                <label for="featured-subtitle" class="form-label">Subtitle</label>
                <input id="featured-subtitle" type="text" bind:value={featuredProductsData.subtitle} class="form-control" />
              </div>
            </div>

            <!-- Products Selection -->
            <div class="form-group">
              <label class="form-label">Select Featured Products</label>
              <div class="product-grid">
                {#each allProducts as product}
                  <div class="product-selector glass-light {featuredProductsData.product_ids.includes(product.id) ? 'selected' : ''}" 
                       on:click={() => toggleProductSelection(product.id, 'featured')}
                       on:keydown={(e) => e.key === 'Enter' && toggleProductSelection(product.id, 'featured')}
                       tabindex="0"
                       role="button">
                    <img src={getProductImage(product.image_url, product.category)} alt={product.name} class="product-image" />
                    <div class="product-info">
                      <h4 class="neon-text-white">{product.name}</h4>
                      <p class="neon-text-cyan">R{product.price}</p>
                    </div>
                    {#if featuredProductsData.product_ids.includes(product.id)}
                      <div class="selected-indicator">✓</div>
                    {/if}
                  </div>
                {/each}
              </div>
            </div>

            <button class="btn btn-primary" on:click={() => saveSection('featured')} disabled={saving}>
              {saving ? 'Saving...' : 'Save Featured Products Section'}
            </button>
          </div>
        </div>
      {/if}

      <!-- Testimonials Section -->
      {#if activeSection === 'testimonials' && testimonialsData}
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Testimonials Section</h2>
          </div>
          <div class="card-body">
            <div class="form-group mb-4">
              <label for="testimonials-title" class="form-label">Section Title</label>
              <input id="testimonials-title" type="text" bind:value={testimonialsData.title} class="form-control" />
            </div>

            <!-- Add New Testimonial -->
            <div class="glass-light p-3 mb-4">
              <h3 class="neon-text-cyan mb-3">Add New Testimonial</h3>
              <div class="grid grid-3 gap-2 mb-3">
                <div class="form-group">
                  <label for="new-test-name" class="form-label">Customer Name</label>
                  <input id="new-test-name" type="text" bind:value={newTestimonial.name} placeholder="e.g., John Doe" class="form-control" />
                </div>
                
                <div class="form-group">
                  <label for="new-test-rating" class="form-label">Rating</label>
                  <select id="new-test-rating" bind:value={newTestimonial.rating} class="form-control form-select">
                    <option value={5}>5 Stars</option>
                    <option value={4}>4 Stars</option>
                    <option value={3}>3 Stars</option>
                    <option value={2}>2 Stars</option>
                    <option value={1}>1 Star</option>
                  </select>
                </div>
                
                <div class="form-group">
                  <label class="checkbox-label">
                    <input type="checkbox" bind:checked={newTestimonial.verified} />
                    Verified Customer
                  </label>
                </div>
              </div>
              
              <div class="form-group mb-3">
                <label for="new-test-comment" class="form-label">Comment</label>
                <textarea id="new-test-comment" bind:value={newTestimonial.comment} rows="2" placeholder="Enter customer review..." class="form-control"></textarea>
              </div>
              
              <button class="btn btn-secondary" on:click={addTestimonial}>Add Testimonial</button>
            </div>

            <!-- Existing Testimonials -->
            <div class="testimonials-list">
              <h3 class="neon-text-cyan mb-3">Current Testimonials</h3>
              {#each testimonialsData.testimonials as testimonial, index}
                <div class="testimonial-item glass-light p-3 mb-3">
                  <div class="grid grid-3 gap-2 mb-2">
                    <div class="form-group">
                      <label class="form-label">Customer Name</label>
                      <input type="text" bind:value={testimonial.name} class="form-control" />
                    </div>
                    
                    <div class="form-group">
                      <label class="form-label">Rating</label>
                      <select bind:value={testimonial.rating} class="form-control form-select">
                        <option value={5}>5 Stars</option>
                        <option value={4}>4 Stars</option>
                        <option value={3}>3 Stars</option>
                        <option value={2}>2 Stars</option>
                        <option value={1}>1 Star</option>
                      </select>
                    </div>
                    
                    <div class="form-group">
                      <div class="flex gap-2 align-center">
                        <label class="checkbox-label">
                          <input type="checkbox" bind:checked={testimonial.verified} />
                          Verified
                        </label>
                        <button class="btn btn-danger btn-sm" on:click={() => removeTestimonial(index)}>Remove</button>
                      </div>
                    </div>
                  </div>
                  
                  <div class="form-group">
                    <label class="form-label">Comment</label>
                    <textarea bind:value={testimonial.comment} rows="2" class="form-control"></textarea>
                  </div>
                </div>
              {/each}
            </div>

            <button class="btn btn-primary" on:click={() => saveSection('testimonials')} disabled={saving}>
              {saving ? 'Saving...' : 'Save Testimonials Section'}
            </button>
          </div>
        </div>
      {/if}
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
  }

  .admin-header {
    margin-bottom: 2rem;
    text-align: center;
  }

  .admin-header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    letter-spacing: 1px;
  }

  .section-nav {
    padding: 1.5rem;
    border-radius: 12px;
  }

  .nav-buttons {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    justify-content: center;
  }

  .product-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
    max-height: 400px;
    overflow-y: auto;
    border: 1px solid var(--border-primary);
    border-radius: 8px;
    padding: 1rem;
    background: var(--bg-glass);
  }

  .product-selector {
    position: relative;
    padding: 1rem;
    border-radius: 8px;
    cursor: pointer;
    transition: var(--transition-fast);
    border: 2px solid transparent;
  }

  .product-selector:hover {
    border-color: var(--neon-cyan);
    box-shadow: var(--shadow-neon-cyan);
  }

  .product-selector.selected {
    border-color: var(--neon-green);
    box-shadow: var(--shadow-neon-cyan);
    background: rgba(67, 233, 123, 0.1);
  }

  .product-image {
    width: 100%;
    height: 80px;
    object-fit: cover;
    border-radius: 4px;
    margin-bottom: 0.5rem;
  }

  .product-info h4 {
    font-size: 0.9rem;
    margin: 0 0 0.25rem;
  }

  .product-info p {
    font-size: 0.8rem;
    margin: 0;
  }

  .selected-indicator {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    background: var(--neon-green);
    color: var(--bg-primary);
    border-radius: 50%;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    font-size: 0.8rem;
  }

  .category-item,
  .testimonial-item {
    border-radius: 8px;
  }

  .color-preview {
    width: 30px;
    height: 30px;
    border-radius: 4px;
    border: 1px solid var(--border-primary);
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
    color: var(--text-primary);
    font-weight: 500;
  }

  .checkbox-label input[type="checkbox"] {
    width: 1.25rem;
    height: 1.25rem;
    margin: 0;
    accent-color: var(--neon-cyan);
  }

  .mt-2 {
    margin-top: 0.5rem;
  }

  .mb-2 {
    margin-bottom: 0.5rem;
  }

  .mb-3 {
    margin-bottom: 1rem;
  }

  .mb-4 {
    margin-bottom: 1.5rem;
  }

  .flex {
    display: flex;
  }

  .gap-2 {
    gap: 0.5rem;
  }

  .align-center {
    align-items: center;
  }

  .category-preview {
    width: 100%;
    height: 200px;
    border-radius: 12px;
    background-size: cover;
    background-position: center;
    position: relative;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid var(--border-primary);
  }

  .category-preview .category-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    border-radius: 12px;
  }

  .category-preview .category-content {
    position: relative;
    z-index: 1;
    text-align: center;
  }

  .category-preview .category-icon {
    font-size: 2rem;
    margin-bottom: 0.5rem;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.7);
  }

  .category-preview h4 {
    font-size: 1.2rem;
    margin: 0 0 0.5rem;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.7);
  }

  .category-preview p {
    font-size: 0.9rem;
    margin: 0;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.7);
  }

  @media (max-width: 768px) {
    .admin-container {
      padding: 1rem;
    }
    
    .admin-header h1 {
      font-size: 2rem;
    }
    
    .nav-buttons {
      flex-direction: column;
      align-items: stretch;
    }
    
    .product-grid {
      grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    }
    
    .category-preview {
      height: 150px;
    }
  }
</style> 