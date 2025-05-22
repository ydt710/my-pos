<script lang="ts">
  import { cartStore } from '$lib/stores/cartStore';
  import { onMount } from 'svelte';
  import { fade, slide } from 'svelte/transition';
  export let activeCategory: string = '';
  export let logoUrl: string = '';
  export let onMenuToggle: () => void = () => {};
  export let onCartToggle: () => void = () => {};
  export let onLogoClick: () => void = () => {};
  
  let isCartAnimating = false;
  let previousCartCount = 0;
  $: cartCount = $cartStore.reduce((sum, item) => sum + item.quantity, 0);
  $: if (cartCount > previousCartCount) {
    isCartAnimating = true;
    setTimeout(() => {
      isCartAnimating = false;
    }, 500);
    previousCartCount = cartCount;
  }

  let spinningCategory: string | null = null;

  const categories = [
    { 
      id: 'joints', 
      name: 'Joints', 
      icon: 'fa-joint',
      background: 'https://mjbizdaily.com/wp-content/uploads/2024/08/Pre-rolls_-joints-_2_.webp'
    },
    { 
      id: 'concentrate', 
      name: 'Extracts',
      icon: 'fa-vial',
      background: 'https://bulkweedinbox.cc/wp-content/uploads/2024/12/Greasy-Pink.jpg'
    },
    { 
      id: 'flower', 
      name: 'Flower', 
      icon: 'fa-cannabis',
      background: 'https://m.foolcdn.com/media/dubs/original_images/Slide_7_-_marijuana_greenhouse.jpg'
    },
    { 
      id: 'edibles', 
      name: 'Edibles', 
      icon: 'fa-cookie',
      background: 'https://longislandinterventions.com/wp-content/uploads/2024/12/Edibles-1.jpg'
    },
    { 
      id: 'headshop', 
      name: 'Headshop', 
      icon: 'fa-store',
      background: 'https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//bongs.webp'
    }
  ];

  function handleCategoryClick(categoryId: string) {
    // Toggle the category if it's already active
    activeCategory = activeCategory === categoryId ? '' : categoryId;
    spinningCategory = categoryId;
    setTimeout(() => {
      spinningCategory = null;
    }, 700); // match animation duration
  }

  // Preload category background images
  onMount(() => {
    categories.forEach(category => {
      const img = new Image();
      img.src = category.background;
    });
  });
</script>

<div class="category-nav">
  <div class="nav-container">
    <div class="nav-left">
      <button class="logo-btn" on:click={onLogoClick} aria-label="Home" tabindex="0" on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { onLogoClick(); } }}>
        <img class="logo" src={logoUrl} alt="Logo" />
      </button>
    </div>

    <div class="nav-center">
      <div class="category-btn-row">
        {#each categories as category}
          <button 
            class="category-button {activeCategory === category.id ? 'active' : ''}"
            on:click={() => handleCategoryClick(category.id)}
            on:keydown={(e) => e.key === 'Enter' && handleCategoryClick(category.id)}
            role="tab"
            aria-selected={activeCategory === category.id}
            aria-controls={`category-${category.id}`}
            data-category={category.id}
            style="background-image: url('{category.background}'); background-size: cover; background-position: center;"
          >
            <div class="category-overlay"></div>
            <div class="image-container">
              <i class="fa-solid {category.icon} {spinningCategory === category.id ? 'spin' : ''}"></i>
            </div>
            <span class="name">{category.name}</span>
          </button>
        {/each}
      </div>
    </div>

    <div class="nav-right">
      <button class="cart-btn" on:click={onCartToggle} aria-label="Open cart" class:cart-animate={isCartAnimating}>
        <i class="fa-solid fa-shopping-cart"></i>
        {#if cartCount > 0}
          <span class="cart-badge" class:cart-animate={isCartAnimating}>{cartCount}</span>
        {/if}
      </button>
      <button class="menu-btn" on:click={onMenuToggle} aria-label="Open menu">
        <i class="fa-solid fa-bars"></i>
      </button>
    </div>
  </div>
</div>

<style>
  .category-nav {
    display: flex;
    align-items: center;
    padding: 1rem;
    margin-bottom: 0;
    user-select: none;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 1;
    position: relative;
    overflow: hidden;
  }

  .nav-container {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    max-width: 1400px;
    margin: 0 auto;
    gap: 2rem;
  }

  .nav-left {
    flex: 0 0 auto;
  }

  .nav-center {
    flex: 1;
    display: flex;
    justify-content: center;
  }

  .nav-right {
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .logo {
    height: 89px;
    width: auto;
    display: block;
    cursor: pointer;
  }

  .category-btn-row {
    
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    justify-content: center;
    gap: 1rem;
    width: 100%;
  }

  .category-button {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    position: relative;
    border: 2px solid transparent;
    border-radius: 50%;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    width: 100px;
    height: 100px;
    outline: none;
    color: #fff;
    overflow: hidden;
    background-size: cover;
    background-position: center;
    background-color: transparent;
    padding: 0;
  }

  .category-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    transition: background-color 0.2s ease;
    border-radius: 50%;
  }

  .category-button:hover .category-overlay {
    background: rgba(0, 0, 0, 0.2);
  }

  .category-button:focus {
    border-color: #007bff;
    box-shadow: 0 0 0 3px rgba(0,123,255,0.25);
  }

  .category-button.active {
    border-color: #007bff;
    transform: translateY(-3px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  }

  .category-button.active .category-overlay {
    background: rgba(0, 123, 255, 0.3);
  }

  .image-container {
    position: relative;
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1;
  }

  .image-container i {
    font-size: 1.5rem;
    transition: transform 0.2s ease;
    color: #fff;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
  }

  .category-button:hover .image-container i {
    transform: scale(1.1);
  }

  .name {
    font-size: 0.8rem;
    font-family: 'Font Awesome 6 Free';
    text-transform: uppercase;
    transition: color 0.2s ease;
    z-index: 1;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
    color: #fff;
    margin-top: 0.5rem;
  }

  .menu-btn, .cart-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #fff;
    padding: 0.5rem;
    display: flex;
    align-items: center;
    transition: color 0.2s;
  }

  .menu-btn:hover, .cart-btn:hover {
    color: #007bff;
  }

  .cart-btn {
    position: relative;
  }

  .cart-badge {
    position: absolute;
    top: 0;
    right: 0;
    background: #dc3545;
    color: white;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    font-size: 0.8rem;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    transition: transform 0.2s, background-color 0.3s;
    z-index: 2;
  }

  @keyframes pop {
    0% { transform: scale(1); }
    25% { transform: scale(1.5); background: #28a745; }
    50% { transform: scale(0.8); }
    75% { transform: scale(1.2); background: #dc3545; }
    100% { transform: scale(1); background: #dc3545; }
  }

  .cart-animate .cart-badge {
    animation: pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  .cart-animate.cart-btn {
    animation: pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .spin {
    animation: spin 0.7s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  .logo-btn {
    background: none;
    border: none;
    padding: 0;
    margin: 0;
    display: block;
    cursor: pointer;
  }

  @media (max-width: 1024px) {
    .category-button {
      width: 80px;
      height: 80px;
    }

    .image-container {
      width: 32px;
      height: 32px;
    }

    .image-container i {
      font-size: 1.2rem;
    }

    .name {
      font-size: 0.7rem;
    }
  }

  @media (max-width: 768px) {
    .nav-container {
      gap: 0.5rem;
      padding: 0 0.5rem;
    }



    .image-container {
      width: 24px;
      height: 24px;
    }

    .image-container i {
      font-size: 1.2rem;
    }

    .name {
      display: none;
    }

    .logo {
      height: 62px;
    }

    .menu-btn, .cart-btn {
      font-size: 1.2rem;
      padding: 0.25rem;
    }

    .category-btn-row {
      gap: 0.5rem;
      
    }
  }

  @media (max-width: 480px) {
    .nav-container {
      gap: 0.25rem;
      padding: 0 0.25rem;
    }

    .category-button {
      width: 70px;
      height: 70px;
    }

    .image-container {
      width: 20px;
      height: 20px;
    }

    .image-container i {
      font-size: 2rem;
    }

  

    .menu-btn, .cart-btn {
      font-size: 1rem;
      padding: 0.2rem;
    }

    .cart-badge {
      width: 16px;
      height: 16px;
      font-size: 0.7rem;
    }
  }
</style> 