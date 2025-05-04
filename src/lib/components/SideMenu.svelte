<script lang="ts">
  import { tick } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  export let visible = false;
  export let toggleVisibility: () => void;

  let menuSidebar: HTMLDivElement;
  let user: any = null;
  let isAdmin = false;

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
  
  // Handle Escape key to close menu
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      toggleVisibility();
    }
  }
  
  const menuItems = [
    { label: 'Home', href: '#' },
    { label: 'Products', href: '#' },
    { label: 'Orders', href: '#' },
    { label: 'Settings', href: '#' },
    { label: 'Contact', href: '#' }
    // Admin will be conditionally rendered below
  ];

  async function logout() {
    await supabase.auth.signOut();
    goto('/login');
  }

  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) goto('/');
  });
</script>

<div 
  class="side-menu {visible ? 'show' : ''}" 
  bind:this={menuSidebar}
  tabindex="-1"
  role="dialog"
  aria-modal="true"
  aria-label="Side menu"
  on:keydown={handleKeydown}
  on:mouseleave={toggleVisibility}
>
  <div class="menu-header">
    <button 
      class="close-btn" 
      aria-label="Close menu" 
      on:click={toggleVisibility}
    >×</button>
  </div>
  
  <nav>
    {#each menuItems as item}
      <a href={item.href} class="menu-item" tabindex={visible ? 0 : -1}>
        {item.label}
      </a>
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
    background: #333;
    color: white;
    padding: 2rem;
    box-shadow: -2px 0 10px rgba(0,0,0,0.1);
    z-index: 15;
    transform: translateX(100%);
    transition: transform 0.3s ease-in-out;
    display: flex;
    flex-direction: column;
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
  }
  
  .close-btn:hover {
    background: #444;
  }
  
  nav {
    display: flex;
    flex-direction: column;
  }

  .menu-item {
    color: white;
    text-decoration: none;
    padding: 1rem 0;
    border-bottom: 1px solid #444;
    transition: 0.2s;
    font-size: 1.1rem;
  }

  .menu-item:hover {
    background: #444;
    padding-left: 10px;
  }
  
  .menu-item:focus {
    outline: 2px solid white;
    outline-offset: 2px;
  }
</style> 