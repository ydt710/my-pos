<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { createEventDispatcher } from 'svelte';
  
  export let visible = false;
  export let onClose: () => void;
  
  const dispatch = createEventDispatcher();
  
  let pendingTransfers: any[] = [];
  let lowStockItems: any[] = [];
  let loading = true;
  let error = '';
  
  type NotificationItem = {
    id: string;
    type: 'transfer' | 'low_stock';
    title: string;
    description: string;
    time: string;
    icon: string;
    iconColor: string;
    urgent?: boolean;
  };
  
  let notifications: NotificationItem[] = [];
  let realtimeChannel: any = null;
  
  async function fetchNotifications() {
    loading = true;
    error = '';
    
    try {
      // Fetch pending transfers
      const { data: transfersData, error: transfersError } = await supabase
        .from('stock_movements')
        .select(`
          id,
          quantity,
          note,
          created_at,
          products!inner(name),
          stock_locations!stock_movements_from_location_id_fkey(name)
        `)
        .eq('type', 'transfer')
        .eq('status', 'pending')
        .order('created_at', { ascending: false });
      
      if (transfersError) {
        console.error('Error fetching transfers:', transfersError);
        pendingTransfers = [];
      } else {
        pendingTransfers = transfersData || [];
      }
      
      // Fetch low stock items
      const { data: lowStockData, error: lowStockError } = await supabase.rpc('get_low_stock_notifications');
      
      if (lowStockError) {
        console.error('Error fetching low stock items:', lowStockError);
        lowStockItems = [];
      } else {
        lowStockItems = lowStockData || [];
      }
      
      // Combine into unified notification format
      buildNotificationsList();
      
    } catch (err) {
      console.error('Error in fetchNotifications:', err);
      error = 'Failed to load notifications';
    } finally {
      loading = false;
    }
  }
  
  function buildNotificationsList() {
    const allNotifications: NotificationItem[] = [];
    
    // Add pending transfers
    pendingTransfers.forEach(transfer => {
      allNotifications.push({
        id: `transfer-${transfer.id}`,
        type: 'transfer',
        title: `Stock Transfer Pending`,
        description: `${transfer.quantity}x ${transfer.products.name} from ${transfer.stock_locations.name}`,
        time: formatTimeAgo(transfer.created_at),
        icon: 'fa-truck',
        iconColor: '#3b82f6', // blue
        urgent: false
      });
    });
    
    // Add low stock items (group by product to avoid duplicates)
    const groupedLowStock = lowStockItems.reduce((acc, item) => {
      if (!acc[item.product_id]) {
        acc[item.product_id] = {
          ...item,
          locations: [item.location_name],
          total_stock: item.current_stock
        };
      } else {
        acc[item.product_id].locations.push(item.location_name);
        acc[item.product_id].total_stock += item.current_stock;
      }
      return acc;
    }, {});
    
    Object.values(groupedLowStock).forEach((item: any) => {
      const isUrgent = item.total_stock === 0;
      allNotifications.push({
        id: `low-stock-${item.product_id}`,
        type: 'low_stock',
        title: isUrgent ? `Out of Stock!` : `Low Stock Alert`,
        description: `${item.product_name}: ${item.total_stock} remaining (min: ${item.low_stock_buffer})`,
        time: 'Stock level check',
        icon: isUrgent ? 'fa-triangle-exclamation' : 'fa-box',
        iconColor: isUrgent ? '#ef4444' : '#f59e0b', // red or amber
        urgent: isUrgent
      });
    });
    
    // Sort by urgency (urgent first), then by type (transfers first)
    notifications = allNotifications.sort((a, b) => {
      if (a.urgent !== b.urgent) return a.urgent ? -1 : 1;
      if (a.type !== b.type) return a.type === 'transfer' ? -1 : 1;
      return 0;
    });
  }
  
  function formatTimeAgo(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  }
  
  function handleNotificationClick(notification: NotificationItem) {
    if (notification.type === 'transfer') {
      // Navigate to stock management page
      dispatch('navigate', { path: '/admin/stock-management' });
    } else if (notification.type === 'low_stock') {
      // Navigate to admin products page
      dispatch('navigate', { path: '/admin' });
    }
    onClose();
  }
  
  function getTotalCount(): number {
    return pendingTransfers.length + Object.keys(lowStockItems.reduce((acc, item) => {
      acc[item.product_id] = true;
      return acc;
    }, {})).length;
  }
  
  onMount(() => {
    if (visible) {
      fetchNotifications();
      
      // Set up realtime subscriptions
      realtimeChannel = supabase
        .channel('notifications_updates')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'stock_movements' }, () => {
          fetchNotifications();
        })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'stock_levels' }, () => {
          fetchNotifications();
        })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, () => {
          fetchNotifications();
        })
        .subscribe();
    }
  });
  
  onDestroy(() => {
    if (realtimeChannel) {
      supabase.removeChannel(realtimeChannel);
    }
  });
  
  // Refetch when dropdown becomes visible
  $: if (visible) {
    fetchNotifications();
  }
</script>

{#if visible}
  <!-- Backdrop -->
  <div class="notification-backdrop" on:click={onClose} on:keydown={(e) => e.key === 'Escape' && onClose()}></div>
  
  <!-- Dropdown -->
  <div class="notification-dropdown glass">
    <div class="notification-header">
      <h3 class="neon-text-cyan">Notifications</h3>
      <button class="close-btn" on:click={onClose}>
        <i class="fa-solid fa-times"></i>
      </button>
    </div>
    
    <div class="notification-content">
      {#if loading}
        <div class="notification-loading">
          <div class="spinner"></div>
          <p class="neon-text-white">Loading notifications...</p>
        </div>
      {:else if error}
        <div class="notification-error">
          <i class="fa-solid fa-triangle-exclamation"></i>
          <p class="neon-text-red">{error}</p>
        </div>
      {:else if notifications.length === 0}
        <div class="notification-empty">
          <i class="fa-solid fa-bell-slash"></i>
          <p class="neon-text-secondary">No notifications</p>
          <small class="neon-text-muted">You're all caught up!</small>
        </div>
      {:else}
        <div class="notification-list">
          {#each notifications as notification}
            <div 
              class="notification-item {notification.urgent ? 'urgent' : ''}"
              on:click={() => handleNotificationClick(notification)}
              on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && handleNotificationClick(notification)}
              tabindex="0"
              role="button"
            >
              <div class="notification-icon" style="color: {notification.iconColor}">
                <i class="fa-solid {notification.icon}"></i>
              </div>
              <div class="notification-text">
                <h4 class="notification-title {notification.urgent ? 'neon-text-red' : 'neon-text-white'}">
                  {notification.title}
                </h4>
                <p class="notification-description neon-text-secondary">
                  {notification.description}
                </p>
                <small class="notification-time neon-text-muted">
                  {notification.time}
                </small>
              </div>
              {#if notification.urgent}
                <div class="urgent-indicator">!</div>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>
    
    {#if notifications.length > 0}
      <div class="notification-footer">
        <button class="btn btn-sm btn-secondary" on:click={onClose}>
          Close
        </button>
      </div>
    {/if}
  </div>
{/if}

<style>
  .notification-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 9999;
    background: transparent;
  }
  
  .notification-dropdown {
    position: fixed;
    top: 90px; /* Below the navigation bar */
    right: 1rem;
    width: 380px;
    max-height: calc(100vh - 120px); /* Leave space at bottom */
    background: var(--bg-secondary);
    border: 2px solid var(--border-primary);
    border-radius: 16px;
    backdrop-filter: blur(20px);
    box-shadow: var(--shadow-neon-cyan);
    z-index: 10000;
    overflow: hidden;
  }
  
  .notification-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid var(--border-primary);
  }
  
  .notification-header h3 {
    margin: 0;
    font-size: 1.2rem;
    font-weight: 600;
  }
  
  .close-btn {
    background: none;
    border: none;
    color: var(--text-secondary);
    font-size: 1.2rem;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    transition: var(--transition-fast);
  }
  
  .close-btn:hover {
    color: var(--neon-cyan);
    background: var(--bg-glass);
  }
  
  .notification-content {
    max-height: 350px;
    overflow-y: auto;
  }
  
  .notification-loading,
  .notification-error,
  .notification-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    text-align: center;
  }
  
  .notification-loading .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid var(--border-primary);
    border-top: 3px solid var(--neon-cyan);
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 1rem;
  }
  
  .notification-error i,
  .notification-empty i {
    font-size: 2rem;
    margin-bottom: 0.5rem;
    opacity: 0.6;
  }
  
  .notification-list {
    padding: 0.5rem 0;
  }
  
  .notification-item {
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    padding: 1rem 1.5rem;
    cursor: pointer;
    transition: var(--transition-fast);
    border-left: 4px solid transparent;
    position: relative;
  }
  
  .notification-item:hover {
    background: var(--bg-glass);
    border-left-color: var(--neon-cyan);
  }
  
  .notification-item.urgent {
    border-left-color: var(--neon-red);
    background: rgba(239, 68, 68, 0.1);
  }
  
  .notification-item.urgent:hover {
    background: rgba(239, 68, 68, 0.2);
  }
  
  .notification-icon {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: var(--bg-glass);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.2rem;
  }
  
  .notification-text {
    flex: 1;
    min-width: 0;
  }
  
  .notification-title {
    margin: 0 0 0.25rem 0;
    font-size: 0.9rem;
    font-weight: 600;
    line-height: 1.3;
  }
  
  .notification-description {
    margin: 0 0 0.25rem 0;
    font-size: 0.8rem;
    line-height: 1.4;
    word-wrap: break-word;
  }
  
  .notification-time {
    font-size: 0.75rem;
    opacity: 0.7;
  }
  
  .urgent-indicator {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: var(--neon-red);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8rem;
    font-weight: bold;
    animation: pulse-urgent 2s infinite;
  }
  
  .notification-footer {
    padding: 1rem 1.5rem;
    border-top: 1px solid var(--border-primary);
    text-align: center;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  @keyframes pulse-urgent {
    0%, 100% { 
      box-shadow: 0 0 5px var(--neon-red);
      transform: scale(1);
    }
    50% { 
      box-shadow: 0 0 20px var(--neon-red);
      transform: scale(1.1);
    }
  }
  
  /* Mobile responsive */
  @media (max-width: 480px) {
    .notification-dropdown {
      width: calc(100vw - 2rem);
      right: 1rem;
      left: 1rem;
      top: 80px; /* Smaller top offset for mobile */
      max-height: calc(100vh - 100px);
    }
  }
  
  /* Tablet responsive */
  @media (max-width: 768px) {
    .notification-dropdown {
      width: calc(100vw - 2rem);
      right: 1rem;
      max-width: 400px;
      top: 85px;
    }
  }
  
  /* Custom scrollbar for notification list */
  .notification-content::-webkit-scrollbar {
    width: 6px;
  }
  
  .notification-content::-webkit-scrollbar-track {
    background: var(--bg-primary);
  }
  
  .notification-content::-webkit-scrollbar-thumb {
    background: var(--border-primary);
    border-radius: 3px;
  }
  
  .notification-content::-webkit-scrollbar-thumb:hover {
    background: var(--neon-cyan);
  }
</style> 