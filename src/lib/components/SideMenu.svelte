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
  let isPosUser = false;
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

  onMount(async () => {
    try {
      const bgData = supabase.storage.from('route420').getPublicUrl('field.webp');
      backgroundUrl = bgData.data.publicUrl;
    } catch (err) {
      console.error('Error getting background URL:', err);
    }

    // Fetch user and profile once on mount
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    user = currentUser;
    if (user) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('is_admin, role')
        .eq('auth_user_id', user.id)
        .maybeSingle();
      isAdmin = !!profile?.is_admin;
      isPosUser = profile?.role === 'pos';
    } else {
      isAdmin = false;
      isPosUser = false;
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
  class="side-menu glass {visible ? 'show' : ''}" 
  bind:this={menuSidebar}
  tabindex="-1"
  role="dialog"
  aria-modal="true"
  aria-label="Side menu"
  on:keydown={handleKeydown}
>
  <div class="menu-header">
    <button 
      class="modal-close" 
      aria-label="Close menu" 
      on:click={toggleVisibility}
    >&times;</button>
  </div>
  
  <nav>
    {#each menuItems as item, i}
      {#if item.requiresAuth && !user}
        <!-- skip protected items for non-logged-in users -->
      {:else if item.label === 'Products'}
        <button 
          type="button" 
          class="menu-item products-toggle" 
          tabindex={visible ? 0 : -1} 
          on:click={() => productsExpanded = !productsExpanded} 
          aria-expanded={productsExpanded}
        >
          {item.label}
          <span class="expand-arrow" aria-hidden="true">{productsExpanded ? '▲' : '▼'}</span>
        </button>
        {#if productsExpanded}
          {#each categories as category}
            <a 
              href="/" 
              class="menu-item category-subitem" 
              tabindex={visible ? 0 : -1}
              on:click|preventDefault={() => { 
                dispatch('selectcategory', { id: category.id }); 
                toggleVisibility(); 
              }}
            >
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
    {#if isAdmin || isPosUser}
      <a href="/admin/stock-management" class="menu-item">Stock Management</a>
    {/if}
    {#if !user}
      <a href="/login" class="menu-item">Login</a>
    {/if}
  </nav>

  {#if user}
    <button class="btn btn-danger logout-button" on:click={logout}>
      Logout
    </button>
  {/if}
</div>

<style>
  .side-menu {
    position: fixed;
    top: 0;
    right: 0;
    width: 280px;
    height: 100%;
    padding: 2rem;
    z-index: 2000;
    transform: translateX(100%);
    transition: transform 0.3s ease-in-out;
    display: flex;
    flex-direction: column;
    border-radius: 12px 0 0 12px;
    border-right: none;
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
  }
  
  nav {
    display: flex;
    flex-direction: column;
    flex: 1;
  }

  .menu-item {
    color: var(--text-secondary);
    text-decoration: none;
    padding: 1rem 0;
    border-bottom: 1px solid var(--border-primary);
    transition: var(--transition-fast);
    font-size: 1.1rem;
    background: none;
    border: none;
    border-bottom: 1px solid var(--border-primary);
    cursor: pointer;
    text-align: left;
    width: 100%;
    font-family: inherit;
  }

  .menu-item:hover {
    color: var(--neon-cyan);
    background: var(--bg-glass-light);
    padding-left: 1rem;
    box-shadow: var(--shadow-neon-cyan);
  }
  
  .menu-item:focus {
    outline: 2px solid var(--neon-cyan);
    outline-offset: 2px;
  }

  .products-toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    color: var(--text-secondary);
    font-size: 1.1rem;
    transition: var(--transition-fast);
  }

  .products-toggle:hover {
    color: var(--neon-cyan);
    background: var(--bg-glass-light);
  }

  .expand-arrow {
    margin-left: 0.5em;
    font-size: 0.9em;
    transition: var(--transition-fast);
  }

  .category-subitem {
    padding-left: 2.5rem;
    font-size: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    border-bottom: 1px solid rgba(178, 254, 250, 0.08);
  }

  .category-subitem:last-child {
    border-bottom: none;
  }

  .category-subitem:hover {
    background: rgba(0, 240, 255, 0.15);
    color: var(--neon-cyan);
  }

  .category-subitem i {
    color: var(--neon-cyan);
  }

  .logout-button {
    margin-top: auto;
    padding: 1rem;
    width: 100%;
  }

  @media (max-width: 800px) {
    .side-menu {
      width: 100%;
      border-radius: 0;
    }
  }
</style> 