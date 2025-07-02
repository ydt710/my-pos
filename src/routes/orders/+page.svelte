<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import type { Order, OrderItem } from '$lib/types/orders';
  import { showSnackbar } from '$lib/stores/snackbarStore';
  import { fade } from 'svelte/transition';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import DatePicker from '$lib/components/DatePicker.svelte';
  import { getProductImage } from '$lib/constants';

  let user: any = null;
  let orders: Order[] = [];
  let allOrders: Order[] = []; // Store all orders for filtering
  let loading = true;
  let error = '';
  let menuVisible = false;
  let cartVisible = false;
  let cartButton: HTMLButtonElement;
  let showConfirmModal = false;
  let orderIdToDelete: string | null = null;

  // Date filtering
  let startDate = new Date();
  let endDate = new Date();
  let startDateStr = '';
  let endDateStr = '';
  let dateFilter: 'all' | 'today' | 'week' | 'month' | 'custom' = 'all';

  // Set default date range
  startDate.setDate(startDate.getDate() - 30); // 30 days ago
  endDate = new Date(); // today

  onMount(async () => {
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser) {
      goto('/login');
      return;
    }
    user = currentUser;
    
    // Initialize date strings
    startDateStr = startDate.toISOString().split('T')[0];
    endDateStr = endDate.toISOString().split('T')[0];
    
    await fetchOrders();
  });

  async function fetchOrders() {
    loading = true;
    error = '';

    try {
      // Get the current user's profile
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();
      if (profileError || !profile) throw profileError || new Error('Profile not found');

      // Fetch orders with their items for this user only
      const { data: ordersData, error: ordersError } = await supabase
        .from('orders')
        .select(`
          *,
          order_items (
            *,
            products:product_id (
              name,
              image_url,
              category
            )
          ),
          profiles:user_id (
            email,
            display_name,
            phone_number,
            address
          )
        `)
        .eq('user_id', profile.id)
        .is('deleted_at', null)
        .order('created_at', { ascending: false });

      if (ordersError) throw ordersError;

      allOrders = (ordersData || []).map(order => ({
        ...order,
        user: order.profiles || undefined
      }));
      
      // Apply current date filter
      applyDateFilter();
    } catch (err) {
      console.error('Error fetching orders:', err);
      error = 'Failed to load orders. Please try again.';
    } finally {
      loading = false;
    }
  }

  function applyDateFilter() {
    const now = new Date();
    let filterStartDate: Date | null = null;
    let filterEndDate: Date | null = null;

    switch (dateFilter) {
      case 'today':
        filterStartDate = new Date(now);
        filterStartDate.setHours(0, 0, 0, 0);
        filterEndDate = new Date(now);
        filterEndDate.setHours(23, 59, 59, 999);
        break;
      case 'week':
        filterStartDate = new Date(now);
        filterStartDate.setDate(now.getDate() - 7);
        filterStartDate.setHours(0, 0, 0, 0);
        filterEndDate = new Date(now);
        filterEndDate.setHours(23, 59, 59, 999);
        break;
      case 'month':
        filterStartDate = new Date(now);
        filterStartDate.setDate(now.getDate() - 30);
        filterStartDate.setHours(0, 0, 0, 0);
        filterEndDate = new Date(now);
        filterEndDate.setHours(23, 59, 59, 999);
        break;
      case 'custom':
        filterStartDate = new Date(startDate);
        filterStartDate.setHours(0, 0, 0, 0);
        filterEndDate = new Date(endDate);
        filterEndDate.setHours(23, 59, 59, 999);
        break;
      case 'all':
      default:
        // Show all orders
        orders = [...allOrders];
        return;
    }

    if (filterStartDate && filterEndDate) {
      orders = allOrders.filter(order => {
        const orderDate = new Date(order.created_at);
        return orderDate >= filterStartDate! && orderDate <= filterEndDate!;
      });
    }
  }

  function setDateFilter(filter: typeof dateFilter) {
    dateFilter = filter;
    applyDateFilter();
  }

  function handleDateStringChange(isStart: boolean, value: string) {
    if (!value) return;
    
    const date = new Date(value + 'T00:00:00');
    if (!isNaN(date.getTime())) {
      if (isStart) {
        startDate = date;
        startDateStr = value;
      } else {
        endDate = date;
        endDateStr = value;
      }
      
      if (dateFilter === 'custom') {
        applyDateFilter();
      }
    }
  }

  async function deleteOrder(orderId: string) {
    loading = true;
    error = '';
    try {
      // Fetch the order and its items
      const { data: orderData, error: fetchOrderError } = await supabase
        .from('orders')
        .select('id, order_items (product_id, quantity)')
        .eq('id', orderId)
        .single();
      if (fetchOrderError) throw fetchOrderError;
      // Reapply stock for each product in the order
      for (const item of orderData.order_items ?? []) {
        await supabase.rpc('increment_product_quantity', {
          product_id: item.product_id,
          amount: item.quantity
        });
      }
      // Soft delete the order and set status to 'cancelled', deleted_by, and deleted_by_role
      const { error: updateError } = await supabase
        .from('orders')
        .update({ 
          deleted_at: new Date().toISOString(), 
          status: 'cancelled', 
          deleted_by: user?.id, 
          deleted_by_role: 'user' 
        })
        .eq('id', orderId);
      if (updateError) throw updateError;
      // Remove from both arrays
      orders = orders.filter(o => o.id !== orderId);
      allOrders = allOrders.filter(o => o.id !== orderId);
      showSnackbar('Order deleted (soft delete) and stock reapplied.');
    } catch (err) {
      console.error('Error deleting order:', err);
      error = 'Failed to delete order. Please try again.';
    } finally {
      loading = false;
    }
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function calculateTotal(items: OrderItem[]) {
    return items.reduce((total, item) => total + (item.quantity * item.price), 0);
  }

  function toggleMenu() {
    menuVisible = !menuVisible;
    if (cartVisible) cartVisible = false;
  }

  function toggleCart() {
    cartVisible = !cartVisible;
    if (menuVisible) menuVisible = false;
  }
</script>

<StarryBackground />

<main class="orders-container">
  <h1>Your Orders</h1>

  <!-- Date Filter Section -->
  <div class="filters-section glass">
    <div class="filter-header">
      <h3 class="neon-text-cyan">Filter Orders</h3>
    </div>
    <div class="filter-controls">
      <div class="filter-buttons">
        <button 
          class="btn btn-sm {dateFilter === 'all' ? 'btn-primary' : 'btn-secondary'}" 
          on:click={() => setDateFilter('all')}
        >
          All Orders
        </button>
        <button 
          class="btn btn-sm {dateFilter === 'today' ? 'btn-primary' : 'btn-secondary'}" 
          on:click={() => setDateFilter('today')}
        >
          Today
        </button>
        <button 
          class="btn btn-sm {dateFilter === 'week' ? 'btn-primary' : 'btn-secondary'}" 
          on:click={() => setDateFilter('week')}
        >
          Last 7 Days
        </button>
        <button 
          class="btn btn-sm {dateFilter === 'month' ? 'btn-primary' : 'btn-secondary'}" 
          on:click={() => setDateFilter('month')}
        >
          Last 30 Days
        </button>
        <button 
          class="btn btn-sm {dateFilter === 'custom' ? 'btn-primary' : 'btn-secondary'}" 
          on:click={() => setDateFilter('custom')}
        >
          Custom Range
        </button>
      </div>
      
      {#if dateFilter === 'custom'}
        <div class="custom-date-range">
          <div class="date-inputs">
            <label class="form-label">From:
              <DatePicker 
                bind:value={startDateStr} 
                placeholder="Start date"
                on:change={(e) => handleDateStringChange(true, e.detail.value)}
              />
            </label>
            <label class="form-label">To:
              <DatePicker 
                bind:value={endDateStr} 
                placeholder="End date"
                on:change={(e) => handleDateStringChange(false, e.detail.value)}
              />
            </label>
          </div>
        </div>
      {/if}
    </div>
    
    <div class="filter-results">
      <p class="neon-text-muted">
        Showing {orders.length} of {allOrders.length} orders
        {#if dateFilter !== 'all'}
          <span class="filter-indicator">({dateFilter === 'custom' ? 'custom date range' : dateFilter})</span>
        {/if}
      </p>
    </div>
  </div>

  {#if error}
    <div class="error-message">{error}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading your orders...</div>
  {:else if orders.length === 0}
    <div class="empty-state">
      <p>You haven't placed any orders yet.</p>
      <button class="shop-now-btn" on:click={() => goto('/')}>Start Shopping</button>
    </div>
  {:else}
    <div class="orders-list">
      {#each orders as order (order.id)}
        <div class="order-card" out:fade>
          <div class="order-header">
            <div class="order-info">
              <h3>Order #{order.order_number || order.id}</h3>
              <p class="order-date">{formatDate(order.created_at)}</p>
            </div>
          </div>

          <div class="order-items">
            {#each order.order_items ?? [] as item}
              <div class="order-item">
                                  <img src={getProductImage(item.product?.image_url, (item.product as any)?.category || 'flower')} alt={item.product?.name} />
                <div class="item-details">
                  <h4>{item.product?.name}</h4>
                  <p class="item-quantity">Quantity: {item.quantity}</p>
                  <p class="item-price">R{item.price} each</p>
                </div>
                <div class="item-total">
                  R{item.quantity * item.price}
                </div>
              </div>
            {/each}
          </div>

          <div class="order-footer">
            <div class="order-total">
              <span>Total:</span>
              <span>R{calculateTotal(order.order_items ?? [])}</span>
            </div>
            <div class="order-actions">
              <button class="reorder-btn" on:click={() => goto('/')}>
                Reorder
              </button>
              <button 
                class="delete-btn" 
                on:click={() => { showConfirmModal = true; orderIdToDelete = order.id.toString(); }}
                aria-label="Delete order"
                disabled={order.status === 'completed' || order.status === 'cancelled'}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</main>

<SideMenu visible={menuVisible} toggleVisibility={toggleMenu} />

{#if showConfirmModal}
  <ConfirmModal
    message="Are you sure you want to delete this order?"
    onConfirm={() => { if (orderIdToDelete) deleteOrder(orderIdToDelete); showConfirmModal = false; orderIdToDelete = null; }}
    onCancel={() => { showConfirmModal = false; orderIdToDelete = null; }}
  />
{/if}

<style>
  :global(body) {
    background: transparent;
  }
  :global(*) {
    position: relative;
    z-index: 1;
  }

  .orders-container {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1rem;
  }

  h1 {
    text-align: center;
    margin-bottom: 2rem;
    color: var(--text-primary);
    text-shadow: 0 0 10px rgba(0, 240, 255, 0.5);
  }

  .orders-list {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .order-card {
    background: var(--bg-glass);
    backdrop-filter: blur(10px);
    border: 1px solid var(--border-primary);
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: var(--shadow-glass);
    transition: var(--transition-fast);
  }

  .order-card:hover {
    border-color: var(--neon-cyan);
    box-shadow: var(--shadow-neon-cyan);
    transform: translateY(-2px);
  }

  .order-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid #eee;
  }

  .order-info h3 {
    margin: 0;
    color: var(--neon-cyan);
    font-size: 1.2rem;
    text-shadow: 0 0 8px rgba(0, 240, 255, 0.4);
  }

  .order-date {
    color: var(--text-muted);
    font-size: 0.9rem;
    margin: 0.25rem 0 0;
  }

  
  .order-items {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .order-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.5rem;
    border-radius: 8px;
    background: #f8f9fa;
  }

  .order-item img {
    width: 60px;
    height: 60px;
    object-fit: cover;
    border-radius: 6px;
  }

  .item-details {
    flex-grow: 1;
  }

  .item-details h4 {
    margin: 0 0 0.25rem;
    color: #333;
    font-size: 1rem;
  }

  .item-quantity {
    color: #666;
    font-size: 0.9rem;
    margin: 0;
  }

  .item-price {
    color: #666;
    font-size: 0.9rem;
    margin: 0;
  }

  .item-total {
    font-weight: 600;
    color: #333;
  }

  .order-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
    border-top: 1px solid #eee;
  }

  .order-total {
    font-size: 1.1rem;
    font-weight: 600;
    color: #333;
  }

  .order-total span:last-child {
    margin-left: 0.5rem;
  }

  .order-actions {
    display: flex;
    gap: 1rem;
  }

  .reorder-btn {
    background: #007bff;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .reorder-btn:hover {
    background: #0056b3;
  }

  .delete-btn {
    background: #dc3545;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .delete-btn:hover {
    background: #bd2130;
  }

  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
  }

  .loading {
    text-align: center;
    padding: 2rem;
    color: #666;
  }

  .empty-state {
    text-align: center;
    padding: 3rem;
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  }

  .empty-state p {
    color: #666;
    margin-bottom: 1.5rem;
  }

  .shop-now-btn {
    display: inline-block;
    background: #28a745;
    color: white;
    text-decoration: none;
    padding: 0.75rem 1.5rem;
    border-radius: 6px;
    transition: background-color 0.2s;
  }

  .shop-now-btn:hover {
    background: #218838;
  }

  @media (max-width: 800px) {
    .orders-container {
      padding: 0 0.5rem;
      margin: 1rem auto;
    }

    h1 {
      font-size: 1.5rem;
      margin-bottom: 1.5rem;
    }

    .order-card {
      padding: 1rem;
    }

    .order-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
      margin-bottom: 0.75rem;
      padding-bottom: 0.75rem;
    }

    .order-info h3 {
      font-size: 1rem;
    }

    .order-item {
      flex-direction: column;
      text-align: center;
      gap: 0.5rem;
      padding: 0.75rem 0.5rem;
    }

    .order-item img {
      width: 50px;
      height: 50px;
      align-self: center;
    }

    .item-details {
      text-align: center;
    }

    .item-details h4 {
      font-size: 0.9rem;
    }

    .item-quantity,
    .item-price {
      font-size: 0.8rem;
    }

    .item-total {
      font-size: 0.9rem;
      margin-top: 0.25rem;
    }

    .order-footer {
      flex-direction: column;
      gap: 1rem;
      text-align: center;
      padding-top: 0.75rem;
    }

    .order-total {
      font-size: 1rem;
    }

    .order-actions {
      flex-direction: column;
      gap: 0.5rem;
    }

    .order-actions button {
      width: 100%;
      padding: 0.75rem;
    }

    .delete-btn:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
  }

  @media (max-width: 480px) {
    .orders-container {
      margin: 0.5rem auto;
    }

    .order-card {
      margin: 0 -0.5rem;
      border-radius: 8px;
    }

    .orders-list {
      gap: 1rem;
    }

    h1 {
      font-size: 1.25rem;
    }
  }

  /* Filter Section Styles */
  .filters-section {
    margin-bottom: 2rem;
    padding: 1.5rem;
    border-radius: 12px;
  }

  .filter-header {
    margin-bottom: 1rem;
  }

  .filter-header h3 {
    margin: 0;
    font-size: 1.1rem;
    font-weight: 600;
  }

  .filter-controls {
    margin-bottom: 1rem;
  }

  .filter-buttons {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
  }

  .custom-date-range {
    margin-top: 1rem;
    padding: 1rem;
    background: var(--bg-glass-light);
    border-radius: 8px;
    border: 1px solid var(--border-primary);
  }

  .date-inputs {
    display: flex;
    gap: 1rem;
    align-items: end;
  }

  .date-inputs label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    min-width: 150px;
  }

  .filter-results p {
    margin: 0;
    font-size: 0.9rem;
  }

  .filter-indicator {
    font-weight: 500;
    color: var(--neon-cyan);
  }

  /* Update other text colors for neon theme */
  .item-details h4 {
    color: var(--text-primary);
  }

  .item-quantity,
  .item-price {
    color: var(--text-muted);
  }

  .item-total {
    color: var(--text-primary);
    font-weight: 600;
  }

  .order-total {
    color: var(--text-primary);
  }

  .order-item {
    background: var(--bg-glass-light);
    border: 1px solid var(--border-primary);
  }

  .empty-state {
    background: var(--bg-glass);
    border: 1px solid var(--border-primary);
    backdrop-filter: blur(10px);
  }

  .empty-state p {
    color: var(--text-muted);
  }

  .error-message {
    background: rgba(220, 53, 69, 0.1);
    color: #dc3545;
    border: 1px solid #dc3545;
  }

  .loading {
    color: var(--text-muted);
  }

  @media (max-width: 768px) {
    .filters-section {
      padding: 1rem;
    }

    .filter-buttons {
      flex-direction: column;
      gap: 0.5rem;
    }

    .date-inputs {
      flex-direction: column;
      gap: 0.75rem;
    }

    .date-inputs label {
      min-width: auto;
      width: 100%;
    }

    .custom-date-range {
      padding: 0.75rem;
    }
  }

  @media (max-width: 480px) {
    .filter-header h3 {
      font-size: 1rem;
    }

    .filter-results p {
      font-size: 0.85rem;
    }
  }
</style> 