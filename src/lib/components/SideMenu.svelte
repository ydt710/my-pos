<script lang="ts">
  import { tick } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { onMount, createEventDispatcher } from 'svelte';

  export let visible = false;
  export let toggleVisibility: () => void;

  let menuSidebar: HTMLDivElement;
  let user: any = null;
  let isAdmin = false;
  let backgroundUrl = '';
  let productsExpanded = false;

  // Category list for dropdown under Products
  const categories = [
    { id: 'joints', name: 'Joints', icon: 'fa-joint' },
    { id: 'concentrate', name: 'Extracts', icon: 'fa-vial' },
    { id: 'flower', name: 'Flower', icon: 'fa-cannabis' },
    { id: 'edibles', name: 'Edibles', icon: 'fa-cookie' },
    { id: 'headshop', name: 'Headshop', icon: 'fa-store' }
  ];

  const dispatch = createEventDispatcher();

  // When the menu becomes visible, focus it for accessibility
  $: if (visible) {
    tick().then(() => menuSidebar?.focus());
  }

  // Check user and admin status on mount and when menu opens
  $: if (visible) {
    supabase.auth.getUser().then(({ data }) => {
      user = data.user;
      isAdmin = !!data.user?.user_metadata?.is_admin;
    });
  }

  onMount(async () => {
    try {
      const bgData = supabase.storage.from('route420').getPublicUrl('field.webp');
      backgroundUrl = bgData.data.publicUrl;
    } catch (err) {
      console.error('Error getting background URL:', err);
    }
  });
  
  // Handle Escape key to close menu
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      toggleVisibility();
    }
  }
  
  const menuItems = [
    { label: 'Home', href: '/' },
    { label: 'Products', href: '/products' },
    { label: 'Orders', href: '/orders', requiresAuth: true },
    { label: 'Settings', href: '/settings', requiresAuth: true },
    { label: 'Contact', href: '/contact' }
    // Admin will be conditionally rendered below
  ];

  async function logout() {
    await supabase.auth.signOut();
    user = null;
    isAdmin = false;
    toggleVisibility(); // Close the menu
    // Clear any stored state
    if (typeof window !== 'undefined') {
      localStorage.clear();
      sessionStorage.clear();
    }
    // Force a full page refresh
    window.location.href = '/';
  }
</script>

<div 
  class="side-menu {visible ? 'show' : ''}" 
  bind:this={menuSidebar}
  tabindex="-1"
  role="dialog"
  aria-modal="true"
  aria-label="Side menu"
  on:keydown={handleKeydown}
  
>
  <div class="menu-header">
    <button 
      class="close-btn" 
      aria-label="Close menu" 
      on:click={toggleVisibility}
    >×</button>
  </div>
  
  <nav>
    {#each menuItems as item, i}
      {#if item.requiresAuth && !user}
        <!-- skip protected items for non-logged-in users -->
      {:else if item.label === 'Products'}
        <button type="button" class="menu-item products-toggle" tabindex={visible ? 0 : -1} on:click={() => productsExpanded = !productsExpanded} aria-expanded={productsExpanded}>
          {item.label}
          <span class="expand-arrow" aria-hidden="true">{productsExpanded ? '▲' : '▼'}</span>
        </button>
        {#if productsExpanded}
          {#each categories as category}
            <a href="/" class="menu-item category-subitem" tabindex={visible ? 0 : -1}
              on:click|preventDefault={() => { dispatch('selectcategory', { id: category.id }); toggleVisibility(); }}>
              <i class="fa-solid {category.icon}"></i> {category.name}
            </a>
          {/each}
        {/if}
      {:else}
        <a href={item.href} class="menu-item" tabindex={visible ? 0 : -1}>
          {item.label}
        </a>
      {/if}
    {/each}
    {#if isAdmin}
      <a href="/admin" class="menu-item">Admin</a>
    {/if}
    {#if !user}
      <a href="/login" class="menu-item">Login</a>
    {/if}
  </nav>

  {#if user}
    <button on:click={logout}>Logout</button>
  {/if}
</div>

<style>
  .side-menu {
    position: fixed;
    top: 0;
    right: 0;
    width: 250px;
    height: 100%;
    
    background-position: center;
    background-size: cover;
    color: white;
    padding: 2rem;
    box-shadow: -2px 0 10px rgba(0,0,0,0.1);
    z-index: 2000;
    transform: translateX(100%);
    transition: transform 0.3s ease-in-out;
    display: flex;
    flex-direction: column;
    backdrop-filter: invert;
    
  }

  .side-menu::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    backdrop-filter: blur(23px);
    z-index: -1;
    
  }

  .side-menu.show {
    transform: translateX(0);
  }
  
  .side-menu:focus {
    outline: none;
  }
  
  .menu-header {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 2rem;
    position: relative;
    z-index: 1;
    
  }
  
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: white;
    padding: 0;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    position: relative;
    z-index: 1;
  }
  
  .close-btn:hover {
    background: rgba(255, 255, 255, 0.1);
  }
  
  nav {
    display: flex;
    flex-direction: column;
    position: relative;
    z-index: 1;
  }

  .menu-item {
    color: white;
    text-decoration: none;
    padding: 1rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    transition: 0.2s;
    font-size: 1.1rem;
    position: relative;
    z-index: 1;
  }

  .menu-item:hover {
    background: rgba(255, 255, 255, 0.1);
    padding-left: 10px;
  }
  
  .menu-item:focus {
    outline: 2px solid rgba(255, 255, 255, 0.5);
    outline-offset: 2px;
  }

  .products-toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    background: none;
    border: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
    padding: 1rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    transition: 0.2s;
    font-size: 1.1rem;
    position: relative;
    z-index: 1;
  }
  .expand-arrow {
    margin-left: 0.5em;
    font-size: 0.9em;
  }
  .category-subitem {
    padding-left: 2.5rem;
    font-size: 1rem;
    background: none;
    border: none;
    color: white;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    transition: background 0.2s;
    text-decoration: none;
  }
  .category-subitem:last-child {
    border-bottom: none;
  }
  .category-subitem:hover {
    background: rgba(0,123,255,0.15);
    color: #007bff;
  }

  .menu-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1999;
  }

  .menu-content {
    position: fixed;
    top: 0;
    right: 0;
    width: 250px;
    height: 100%;
    background: #333;
    background-position: center;
    background-size: cover;
    color: white;
    padding: 2rem;
    box-shadow: -2px 0 10px rgba(0,0,0,0.1);
    z-index: 2000;
    transform: translateX(100%);
    transition: transform 0.3s ease-in-out;
    display: flex;
    flex-direction: column;
  }

  .menu-content::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(51, 51, 51, 0.85);
    z-index: -1;
  }

  .menu-content.show {
    transform: translateX(0);
  }
  
  .menu-content:focus {
    outline: none;
  }
  
  .menu-header {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 2rem;
    position: relative;
    z-index: 1;
  }
  
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: white;
    padding: 0;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    position: relative;
    z-index: 1;
  }
  
  .close-btn:hover {
    background: rgba(255, 255, 255, 0.1);
  }
  
  nav {
    display: flex;
    flex-direction: column;
    position: relative;
    z-index: 1;
  }

  .menu-item {
    color: white;
    text-decoration: none;
    padding: 1rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    transition: 0.2s;
    font-size: 1.1rem;
    position: relative;
    z-index: 1;
  }

  .menu-item:hover {
    background: rgba(255, 255, 255, 0.1);
    padding-left: 10px;
  }
  
  .menu-item:focus {
    outline: 2px solid rgba(255, 255, 255, 0.5);
    outline-offset: 2px;
  }

  .products-toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    background: none;
    border: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
    padding: 1rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    transition: 0.2s;
    font-size: 1.1rem;
    position: relative;
    z-index: 1;
  }
  .expand-arrow {
    margin-left: 0.5em;
    font-size: 0.9em;
  }
  .category-subitem {
    padding-left: 2.5rem;
    font-size: 1rem;
    background: none;
    border: none;
    color: white;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    border-bottom: 1px solid rgba(255,255,255,0.08);
    transition: background 0.2s;
    text-decoration: none;
  }
  .category-subitem:last-child {
    border-bottom: none;
  }
  .category-subitem:hover {
    background: rgba(0,123,255,0.15);
    color: #007bff;
  }
</style> 