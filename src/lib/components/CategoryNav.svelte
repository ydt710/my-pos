<script lang="ts">
  import { cartStore } from '$lib/stores/cartStore';
  import { onMount, createEventDispatcher, onDestroy } from 'svelte';
  import { fade, slide } from 'svelte/transition';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import NotificationDropdown from './NotificationDropdown.svelte';
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
    cartAnimationTimeout = setTimeout(() => {
      isCartAnimating = false;
    }, 500);
    previousCartCount = cartCount;
  }

  let spinningCategory: string | null = null;
  let cartAnimationTimeout: ReturnType<typeof setTimeout>;
  let categorySpinTimeout: ReturnType<typeof setTimeout>;

  const dispatch = createEventDispatcher();

  let pendingTransfers = 0;
  let lowStockCount = 0;
  let pendingOrdersCount = 0;
  let totalNotificationCount = 0;
  let showNotifications = false;
  let shopId = 'e0ff9565-e490-45e9-991f-298918e4514a'; // Shop location UUID
  let transferChannel: any;

  let isPosOrAdmin = false;

  async function fetchPendingTransfers() {
    try {
      // Use the database function to get pending shop transfers count
      const { data, error } = await supabase.rpc('get_pending_shop_transfers_count');
      if (!error && typeof data === 'number') {
        pendingTransfers = data;
      } else {
        console.error('Error fetching pending transfers:', error);
        pendingTransfers = 0;
      }
    } catch (err) {
      console.error('Error in fetchPendingTransfers:', err);
      pendingTransfers = 0;
    }
  }

  async function fetchLowStockCount() {
    try {
      const { data, error } = await supabase.rpc('get_low_stock_notifications');
      if (!error && data) {
        // Count unique products in low stock
        const uniqueProducts = new Set(data.map((item: any) => item.product_id));
        lowStockCount = uniqueProducts.size;
      } else {
        console.error('Error fetching low stock count:', error);
        lowStockCount = 0;
      }
    } catch (err) {
      console.error('Error in fetchLowStockCount:', err);
      lowStockCount = 0;
    }
  }

  async function fetchPendingOrdersCount() {
    try {
      // Fetch pending orders for current user
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        // Get the current user's profile
        const { data: profile, error: profileError } = await supabase
          .from('profiles')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();
        
        if (profile && !profileError) {
          // Count pending orders for this user
          const { count, error: ordersError } = await supabase
            .from('orders')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', profile.id)
            .eq('status', 'pending')
            .is('deleted_at', null);

          if (ordersError) {
            console.error('Error fetching pending orders count:', ordersError);
            pendingOrdersCount = 0;
          } else {
            pendingOrdersCount = count || 0;
          }
        } else {
          pendingOrdersCount = 0;
        }
      } else {
        pendingOrdersCount = 0;
      }
    } catch (err) {
      console.error('Error in fetchPendingOrdersCount:', err);
      pendingOrdersCount = 0;
    }
  }

  async function fetchAllNotifications() {
    await Promise.all([fetchPendingTransfers(), fetchLowStockCount(), fetchPendingOrdersCount()]);
    totalNotificationCount = pendingTransfers + lowStockCount + pendingOrdersCount;
  }

  function toggleNotifications() {
    showNotifications = !showNotifications;
  }

  function closeNotifications() {
    showNotifications = false;
  }

  function handleNotificationNavigate(event: CustomEvent) {
    const { path } = event.detail;
    goto(path);
    closeNotifications();
  }

  import { CATEGORY_CONFIG } from '$lib/constants';

  const categories = Object.values(CATEGORY_CONFIG);

  function handleCategoryClick(categoryId: string) {
    // Toggle the category if it's already active
    const newCategory = activeCategory === categoryId ? '' : categoryId;
    dispatch('selectcategory', { id: newCategory });
    spinningCategory = categoryId;
    categorySpinTimeout = setTimeout(() => {
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

  onMount(async () => {
    // Fetch user profile to determine role
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('role, is_admin')
        .eq('auth_user_id', user.id)
        .maybeSingle();
      isPosOrAdmin = profile?.role === 'pos' || profile?.is_admin === true;
    }
    await fetchAllNotifications();
    // Subscribe to Realtime changes on stock_movements and orders
    transferChannel = supabase
      .channel('pending_stock_movements_nav')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'stock_movements' }, async (payload) => {
        // Update for any changes to pending shop transfers
        const rec = payload.new || payload.old;
        if (
          rec &&
          typeof rec === 'object' &&
          'status' in rec &&
          'type' in rec &&
          'to_location_id' in rec &&
          (rec.status === 'pending' || payload.eventType === 'DELETE' || payload.eventType === 'UPDATE') &&
          rec.type === 'transfer' &&
          rec.to_location_id === shopId
        ) {
          await fetchAllNotifications();
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, async (payload) => {
        // Update for any changes to orders (especially status changes)
        const rec = payload.new || payload.old;
        if (rec && typeof rec === 'object' && 'status' in rec) {
          await fetchAllNotifications();
        }
      })
      .subscribe();
  });

  onDestroy(() => {
    // Clear any pending timeouts to prevent memory leaks
    clearTimeout(cartAnimationTimeout);
    clearTimeout(categorySpinTimeout);
    
    // Properly unsubscribe and remove the realtime channel
    if (transferChannel) {
      supabase.removeChannel(transferChannel);
      transferChannel = null;
    }
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
      {#if isPosOrAdmin}
        <div class="notification-wrapper">
          <button class="notification-btn" aria-label="Notifications" on:click={toggleNotifications}>
            <i class="fa-solid fa-bell"></i>
            {#if totalNotificationCount > 0}
              <span class="notification-badge">{totalNotificationCount}</span>
            {/if}
          </button>
          <NotificationDropdown 
            visible={showNotifications} 
            onClose={closeNotifications}
            on:navigate={handleNotificationNavigate}
          />
        </div>
      {/if}
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

<!-- Mobile floating action buttons -->
<div class="mobile-fab-container">
  <button class="mobile-fab" on:click={onCartToggle} aria-label="Open cart">
    <i class="fa-solid fa-shopping-cart"></i>
    {#if cartCount > 0}
      <span class="cart-badge">{cartCount}</span>
    {/if}
  </button>
  {#if isPosOrAdmin}
    <button class="mobile-fab" on:click={toggleNotifications} aria-label="Notifications">
      <i class="fa-solid fa-bell"></i>
      {#if totalNotificationCount > 0}
        <span class="notification-badge">{totalNotificationCount}</span>
      {/if}
    </button>
  {/if}
  <button class="mobile-fab" on:click={onMenuToggle} aria-label="Open menu">
    <i class="fa-solid fa-bars"></i>
  </button>
</div>

<!-- Mobile notification dropdown positioning -->
{#if isPosOrAdmin && showNotifications}
  <div class="mobile-notification-dropdown">
    <NotificationDropdown 
      visible={showNotifications} 
      onClose={closeNotifications}
      on:navigate={handleNotificationNavigate}
    />
  </div>
{/if}

<style>
  .category-nav {
    display: flex;
    align-items: center;
    padding: 1rem;
    margin-bottom: 0;
    user-select: none;
    position: relative;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100; /* Lower z-index than notification dropdown */
   
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
    height: 188px;
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

  .category-button:hover {
    box-shadow: 
      0 0 20px rgba(0, 240, 255, 0.6),
      0 0 40px rgba(0, 240, 255, 0.4),
      0 0 60px rgba(0, 240, 255, 0.2),
      0 2px 8px rgba(0, 0, 0, 0.3);
    border-color: rgba(0, 240, 255, 0.5);
    transform: translateY(-2px);
  }

  .category-button:focus {
    border-color: #00f0ff;
    box-shadow: 
      0 0 0 3px rgba(0, 240, 255, 0.5),
      0 0 25px rgba(0, 240, 255, 0.8),
      0 0 50px rgba(0, 240, 255, 0.4);
  }

  .category-button.active {
    border-color: #00f0ff;
    transform: translateY(-5px);
    box-shadow: 
      0 0 25px rgba(0, 240, 255, 0.8),
      0 0 50px rgba(0, 240, 255, 0.6),
      0 0 75px rgba(0, 240, 255, 0.4),
      0 0 100px rgba(255, 0, 222, 0.3),
      0 6px 20px rgba(0, 0, 0, 0.4);
    animation: pulse-glow 2s ease-in-out infinite alternate;
  }

  .category-button.active .category-overlay {
    background: rgba(0, 240, 255, 0.3);
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
    transition: all 0.3s ease;
    color: #fff;
    text-shadow: 
      0 0 10px rgba(0, 240, 255, 0.8),
      0 0 20px rgba(0, 240, 255, 0.6),
      0 2px 4px rgba(0, 0, 0, 0.8);
    filter: drop-shadow(0 0 8px rgba(0, 240, 255, 0.6));
  }

  .category-button:hover .image-container i {
    transform: scale(1.2);
    text-shadow: 
      0 0 15px rgba(0, 240, 255, 1),
      0 0 30px rgba(0, 240, 255, 0.8),
      0 2px 4px rgba(0, 0, 0, 0.8);
    filter: drop-shadow(0 0 12px rgba(0, 240, 255, 0.8));
  }

  .category-button.active .image-container i {
    transform: scale(1.3);
    text-shadow: 
      0 0 20px rgba(0, 240, 255, 1),
      0 0 40px rgba(0, 240, 255, 0.8),
      0 0 60px rgba(255, 255, 255, 0.4),
      0 2px 4px rgba(0, 0, 0, 0.8);
    filter: drop-shadow(0 0 15px rgba(0, 240, 255, 1));
  }

  .name {
    font-size: 0.8rem;
    font-family: 'Font Awesome 6 Free';
    text-transform: uppercase;
    transition: all 0.3s ease;
    z-index: 1;
    text-shadow: 
      0 0 8px rgba(0, 240, 255, 0.6),
      0 0 16px rgba(0, 240, 255, 0.4),
      0 2px 4px rgba(0, 0, 0, 0.8);
    color: #fff;
    margin-top: 0.5rem;
  }

  .category-button:hover .name {
    text-shadow: 
      0 0 12px rgba(0, 240, 255, 0.8),
      0 0 24px rgba(0, 240, 255, 0.6),
      0 2px 4px rgba(0, 0, 0, 0.8);
  }

  .category-button.active .name {
    text-shadow: 
      0 0 15px rgba(0, 240, 255, 1),
      0 0 30px rgba(0, 240, 255, 0.8),
      0 0 45px rgba(255, 255, 255, 0.3),
      0 2px 4px rgba(0, 0, 0, 0.8);
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

  @keyframes pulse-glow {
    0% { 
      box-shadow: 
        0 0 25px rgba(0, 240, 255, 0.8),
        0 0 50px rgba(0, 240, 255, 0.6),
        0 0 75px rgba(0, 240, 255, 0.4),
        0 0 100px rgba(255, 0, 222, 0.3),
        0 6px 20px rgba(0, 0, 0, 0.4);
    }
    100% { 
      box-shadow: 
        0 0 30px rgba(0, 240, 255, 1),
        0 0 60px rgba(0, 240, 255, 0.8),
        0 0 90px rgba(0, 240, 255, 0.6),
        0 0 120px rgba(255, 0, 222, 0.4),
        0 8px 25px rgba(0, 0, 0, 0.5);
    }
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

  .notification-wrapper {
    position: static;
    display: inline-flex;
    align-items: center;
  }

  .notification-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #fff;
    padding: 0.5rem;
    display: flex;
    align-items: center;
    position: relative;
    transition: color 0.2s;
  }

  .notification-btn:hover {
    color: #007bff;
  }

  .notification-badge {
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

  /* Tablet and small desktop */
  @media (max-width: 1024px) and (min-width: 769px) {
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

  /* Mobile Large (768px and below) */
  @media (max-width: 768px) and (min-width: 641px) {
    .nav-container {
      gap: 0.75rem;
      padding: 0 0.75rem;
    }

    .nav-right {
      display: none; /* Hide nav-right on mobile to center categories */
    }

    .category-button {
      width: 75px;
      height: 75px;
    }

    .image-container {
      width: 28px;
      height: 28px;
    }

    .image-container i {
      font-size: 1.3rem;
    }

    .name {
      font-size: 0.65rem;
    }

    .logo {
      height: 65px;
    }

    .category-btn-row {
      gap: 0.6rem;
    }
  }

  /* Mobile Medium (640px and below) */
  @media (max-width: 640px) and (min-width: 481px) {
    .nav-container {
      gap: 0.6rem;
      padding: 0 0.6rem;
    }

    .nav-right {
      display: none; /* Hide nav-right on mobile to center categories */
    }

    .category-button {
      width: 70px;
      height: 70px;
    }

    .image-container {
      width: 26px;
      height: 26px;
    }

    .image-container i {
      font-size: 1.2rem;
    }

    .name {
      font-size: 0.6rem;
    }

    .logo {
      height: 62px;
    }

    .category-btn-row {
      gap: 0.5rem;
    }
  }

  /* Mobile Small (480px and below) */
  @media (max-width: 480px) {
    .nav-container {
      gap: 0.25rem;
      padding: 0 0.25rem;
      justify-content: center; /* Center everything on mobile */
    }

    .nav-left {
      display: none; /* Hide logo on mobile - will be repositioned in hero section */
    }

    .nav-center {
      flex: none; /* Don't stretch to fill space */
      margin: 0 auto; /* Center the categories */
    }

    .nav-right {
      display: none; /* Keep hidden on mobile */
    }

    .category-button {
      width: 60px;
      height: 60px;
    }

    .image-container {
      width: 20px;
      height: 20px;
    }

    .image-container i {
      font-size: 1.1rem;
    }

    .name {
      display: none;
    }

    .logo {
      height: 50px;
    }

    .category-btn-row {
      gap: 0.3rem;
    }
  }

  /* Mobile floating action buttons */
  .mobile-fab-container {
    position: fixed;
    bottom: 2rem;
    right: 1rem;
    display: none;
    flex-direction: column;
    gap: 0.75rem;
    z-index: 1000;
  }

  .mobile-fab {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: var(--gradient-primary);
    border: none;
    color: white;
    font-size: 1.4rem;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }

  .mobile-fab:hover {
    transform: scale(1.1);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.4);
  }

  .mobile-fab .notification-badge,
  .mobile-fab .cart-badge {
    position: absolute;
    top: -2px;
    right: -2px;
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
    border: 2px solid white;
  }

  @media (max-width: 800px) {
    .mobile-fab-container {
      display: flex;
    }
  }

  /* Mobile notification dropdown */
  .mobile-notification-dropdown {
    position: fixed;
    bottom: 2rem;
    right: 5rem;
    z-index: 999;
    display: none;
  }

  @media (max-width: 800px) {
    .mobile-notification-dropdown {
      display: block;
    }
    
    /* Hide the original notification dropdown on mobile */
    .nav-right .notification-wrapper :global(.notification-dropdown) {
      display: none !important;
    }
  }
</style> 