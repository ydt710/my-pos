<script lang="ts">
  import { cartStore } from '$lib/stores/cartStore';
  import { onMount } from 'svelte';
  import { fade, slide } from 'svelte/transition';
  export let activeCategory: string = '';
  export let backgroundUrl: string = '';
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
      icon: 'fa-joint'
    },
    { 
      id: 'concentrate', 
      name: 'Extracts',
      icon: 'fa-vial'
    },
    { 
      id: 'flower', 
      name: 'Flower', 
      icon: 'fa-cannabis'
    },
    { 
      id: 'edibles', 
      name: 'Edibles', 
      icon: 'fa-cookie'
    },
    { 
      id: 'headshop', 
      name: 'Headshop', 
      icon: 'fa-store' 
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
</script>

<div
  class="category-nav"
>
  {#if backgroundUrl}
    <div class="category-nav-bg" in:slide={{ duration: 600 }} out:fade={{ duration: 400 }} style="background-image: url('{backgroundUrl}');"></div>
  {/if}
  <div class="nav-top-bar">
    <div class="nav-actions nav-left">
      <!-- Empty for spacing, or add left-side actions here if needed -->
    </div>
    <button class="logo-btn" on:click={onLogoClick} aria-label="Home" tabindex="0" on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { onLogoClick(); } }}>
      <img class="logo" src={logoUrl} alt="Logo" />
    </button>
    <div class="nav-actions nav-right">
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
      >
        <div class="image-container">
          <i class="fa-solid {category.icon} {spinningCategory === category.id ? 'spin' : ''}"></i>
        </div>
        <span class="name">{category.name}</span>
      </button>
    {/each}
  </div>
</div>

<style>
  .category-nav {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 0.5rem;
    padding: 1rem;
    margin-bottom: 0;
    user-select: none;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 5;
    background-color: white;
    position: relative;
    overflow: hidden;
  }
  .nav-top-bar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    margin-bottom: 0.5rem;
    z-index: 2;
    position: relative;
  }
  .logo {
    height: 48px;
    width: auto;
    display: block;
    
    left: 50%;
    transform: translateX(-50%);
    z-index: 1;
    cursor: pointer;
  }
  .nav-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    min-width: 80px;
    z-index: 2;
  }
  .nav-left {
    flex: 1;
    justify-content: flex-start;
  }
  .nav-right {
    flex: 1;
    justify-content: flex-end;
  }
  .menu-btn, .cart-btn {
    background: none;
    border: none;
    font-size: 2rem;
    cursor: pointer;
    color: #333;
    padding: 0 1rem;
    display: flex;
    align-items: center;
    transition: color 0.2s;
  }
  .menu-btn:hover, .cart-btn:hover {
    color: #007bff;
  }
  .category-btn-row {
    display: flex;
    justify-content: center;
    gap: 1.5rem;
    width: 100%;
  }
  .category-nav::before {
    content: "";
    position: absolute;
    inset: 0;
    background: rgba(255,255,255,0.7);
    z-index: 0;
    pointer-events: none;
  }
  .category-nav > * {
    position: relative;
    z-index: 1;
  }

  .category-button {
    display: flex;
    flex-direction: column;
    align-items: center;
    
    border: 2px solid transparent;
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    min-width: 120px;
    outline: none;
  }

  .category-button:hover {
    transform: translateY(-3px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    border-color: #007bff;
  }

  .category-button:focus {
    border-color: #007bff;
    box-shadow: 0 0 0 3px rgba(0,123,255,0.25);
  }

  .category-button.active {
    background: #007bff;
    color: white;
    border-color: #007bff;
    transform: translateY(-3px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  }

  .image-container {
    position: relative;
    width: 60px;
    height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .image-container i {
    font-size: 2rem;
    transition: transform 0.2s ease;
  }

  .category-button:hover .image-container i {
    transform: scale(1.1);
  }

  .name {
    font-size: 1rem;
    font-weight: 600;
    text-transform: uppercase;
    transition: color 0.2s ease;
  }

  @media (max-width: 768px) {
    .category-nav {
      flex-wrap: wrap;
      gap: 0.5rem;
      height: auto;
      min-height: 120px;
      align-content: flex-start;
      justify-content: flex-start;
    }

    .category-button {
      padding: 0.5rem;
      min-width: 0;
      flex: 1 1 calc(33.333% - 0.5rem);
      max-width: calc(33.333% - 0.5rem);
    }

    .image-container {
      width: 32px;
      height: 32px;
    }

    .image-container i {
      font-size: 1.2rem;
    }

    .name {
      font-size: 0.55rem
    }
  }

  @media (max-width: 480px) {
    .category-nav {
      min-height: 100px;
    }

    .category-button {
      padding: 0.3rem;
      min-width: 50px;
    }

    .image-container {
      width: 24px;
      height: 24px;
    }

    .image-container i {
      font-size: 1rem;
    }

    .name {
      font-size: 0.6rem;
    }
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
  .category-nav-bg {
    position: absolute;
    inset: 0;
    background-size: cover;
    background-position: center;
    z-index: 0;
    transition: background-image 0.3s;
    pointer-events: none;
  }
  .category-nav-bg::after {
    content: "";
    position: absolute;
    inset: 0;
    background: rgba(0,0,0,0.45);
    z-index: 1;
    pointer-events: none;
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
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    z-index: 1;
  }
</style> 