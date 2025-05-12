<script lang="ts">
  import { cartStore } from '$lib/stores/cartStore';
  import { supabase } from '$lib/supabase';
  import { onMount } from 'svelte';
  
  export let onCartToggle: () => void;
  export let onMenuToggle: () => void;
  export let onLogoClick: () => void;
  
  let isCartAnimating = false;
  let previousCartCount = 0;
  let logoUrl = '';
  let backgroundUrl = '';
  
  $: cartCount = $cartStore.reduce((sum, item) => sum + item.quantity, 0);
  $: if (cartCount > previousCartCount) {
    isCartAnimating = true;
    setTimeout(() => {
      isCartAnimating = false;
    }, 500);
    previousCartCount = cartCount;
  }

  onMount(async () => {
    try {
      // Get the public URL for the logo
      const logoData = supabase.storage.from('route420').getPublicUrl('logo.png');
      logoUrl = logoData.data.publicUrl;
      
      // Get the public URL for the background
      const bgData = supabase.storage.from('route420').getPublicUrl('field.jpeg');
      backgroundUrl = bgData.data.publicUrl;
    } catch (err) {
      console.error('Error getting URLs:', err);
    }
  });
</script>

<div class="navbar" role="navigation" aria-label="Main navigation" style="background-image: url('{backgroundUrl}')">
  <div class="left"></div>
  <div class="center">
    <button 
      class="logo-button" 
      on:click={onLogoClick}
      aria-label="Return to home"
    >
      <div class="logo-area">
        {#if logoUrl}
          <img src={logoUrl} alt="Route 420 Logo" class="logo" />
        {:else}
          <span class="fallback-logo">🪴</span>
        {/if}
      </div>
    </button>
  </div>
  <div class="right">
    <button 
      on:click={onCartToggle}
      aria-label="Shopping cart"
      class="cart-button"
      class:cart-animate={isCartAnimating}
    >
      🛒
      {#if cartCount > 0}
        <span class="cart-badge" class:cart-animate={isCartAnimating}>{cartCount}</span>
      {/if}
    </button>
    <button 
      on:click={onMenuToggle}
      aria-label="Open menu"
    >☰</button>
  </div>
</div>

<style>
  .navbar {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    background: #333;
    background-position: center;
    background-size: cover;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 2rem;
    z-index: 10;
  }

  .navbar::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(51, 51, 51, 0.85);
    z-index: -1;
  }

  .navbar .left {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: flex-start;
  }

  .navbar .center {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    height: 100%;
    display: flex;
    align-items: center;
    z-index: 2;
    overflow: visible;
  }

  .navbar .right {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.5rem;
    z-index: 2;
  }

  .logo {
    width: 95%;
    height: 95%;
    object-fit: contain;
    display: block;
  }

  .fallback-logo {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 2.5rem;
  }

  .navbar button {
    background: none;
    border: none;
    color: white;
    font-size: 1.5rem;
    cursor: pointer;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 8px;
    transition: color 0.2s;
  }
  
  .navbar button:hover {
    color: #ccc;
  }
  
  .navbar button:focus {
    outline: 2px solid white;
    outline-offset: 2px;
  }
  
  .cart-button {
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
  }
  
  @keyframes pop {
    0% {
      transform: scale(1);
    }
    25% {
      transform: scale(1.5);
      background: #28a745;
    }
    50% {
      transform: scale(0.8);
    }
    75% {
      transform: scale(1.2);
      background: #dc3545;
    }
    100% {
      transform: scale(1);
      background: #dc3545;
    }
  }

  .cart-animate .cart-badge {
    animation: pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @keyframes cartBounce {
    0% {
      transform: scale(1);
    }
    25% {
      transform: scale(1.15) rotate(10deg);
    }
    50% {
      transform: scale(0.95) rotate(-5deg);
    }
    75% {
      transform: scale(1.05) rotate(2deg);
    }
    100% {
      transform: scale(1) rotate(0);
    }
  }

  .cart-animate.cart-button {
    animation: cartBounce 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @media (max-width: 768px) {
    .logo {
      height: 76px;
    }
  }

  .logo-button {
    background: none;
    border: none;
    width: 100px;
    height: 100px;
    padding: 0;
    cursor: pointer;
    transition: transform 0.2s ease;
    display: block;
  }

  .logo-area {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }

  .logo-button:hover {
    transform: scale(1.05);
  }

  .logo-button:focus {
    outline: 2px solid white;
    outline-offset: 2px;
  }
</style> 