<script lang="ts">
  import { cartStore } from '$lib/stores/cartStore';
  import { supabase } from '$lib/supabase';
  
  export let onCartToggle: () => void;
  export let onMenuToggle: () => void;
  export let onLogoClick: () => void;
  
  export let cartButton: HTMLButtonElement;
  
  $: cartCount = $cartStore.reduce((sum, item) => sum + item.quantity, 0);

  // Get the public URL for the logo
  let logoUrl = '';
  try {
    const { data } = supabase.storage.from('route420').getPublicUrl('logo.png');
    logoUrl = data.publicUrl;
  } catch (err) {
    console.error('Error getting logo URL:', err);
  }
</script>

<div class="navbar" role="navigation" aria-label="Main navigation">
  <div class="center">
    <button 
      class="logo-button" 
      on:click={onLogoClick}
      aria-label="Return to home"
    >
      {#if logoUrl}
        <img src={logoUrl} alt="Route 420 Logo" class="logo" />
      {:else}
        <span class="fallback-logo">🪴</span>
      {/if}
    </button>
  </div>
  <div class="right">
    <button 
      bind:this={cartButton} 
      on:click={onCartToggle}
      aria-label="Shopping cart"
      class="cart-button"
    >
      🛒
      {#if cartCount > 0}
        <span class="cart-badge">{cartCount}</span>
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
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 2rem;
    z-index: 10;
  }

  .navbar .center,
  .navbar .right {
    display: flex;
    align-items: center;
  }

  .navbar .center {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    height: 100%;
    display: flex;
    align-items: center;
  }

  .logo {
    height: 40px;
    width: auto;
    object-fit: contain;
    display: block;
  }

  .fallback-logo {
    font-size: 2rem;
    line-height: 1;
  }

  .brand {
    font-size: 1.5rem;
    font-weight: bold;
    color: white;
  }

  .navbar button {
    background: none;
    border: none;
    color: white;
    font-size: 1.5rem;
    cursor: pointer;
    margin-left: 15px;
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
  }
  
  @keyframes pop {
    0% { transform: scale(1.5); }
    25% { transform: scale(1.3); }
    50% { transform: scale(0.9); }
    75% { transform: scale(1.1); }
    100% { transform: scale(1); }
  }

  .cart-animate {
    animation: pop 0.5s ease;
  }

  @media (max-width: 768px) {
    .brand {
      display: none;
    }
    
    .logo {
      height: 35px;
    }
  }

  .logo-button {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    transition: transform 0.2s ease;
  }

  .logo-button:hover {
    transform: scale(1.05);
  }

  .logo-button:focus {
    outline: 2px solid white;
    outline-offset: 2px;
  }
</style> 