<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import Navbar from '$lib/components/Navbar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import type { Order, OrderItem } from '$lib/types';

  let user: any = null;
  let orders: Order[] = [];
  let loading = true;
  let error = '';
  let menuVisible = false;
  let cartVisible = false;
  let cartButton: HTMLButtonElement;

  onMount(async () => {
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser) {
      goto('/login');
      return;
    }
    user = currentUser;
    await fetchOrders();
  });

  async function fetchOrders() {
    loading = true;
    error = '';

    try {
      // Fetch orders with their items
      const { data: ordersData, error: ordersError } = await supabase
        .from('orders')
        .select(`
          *,
          order_items (
            *,
            product:products (
              name,
              price,
              image_url
            )
          )
        `)
        .order('created_at', { ascending: false });

      if (ordersError) throw ordersError;

      orders = ordersData || [];
    } catch (err) {
      console.error('Error fetching orders:', err);
      error = 'Failed to load orders. Please try again.';
    } finally {
      loading = false;
    }
  }

  async function deleteOrder(orderId: number) {
    if (!confirm('Are you sure you want to delete this order? This action cannot be undone.')) {
      return;
    }

    loading = true;
    error = '';

    try {
      // First delete the order items
      const { error: itemsError } = await supabase
        .from('order_items')
        .delete()
        .eq('order_id', orderId);

      if (itemsError) throw itemsError;

      // Then delete the order
      const { error: orderError } = await supabase
        .from('orders')
        .delete()
        .eq('id', orderId);

      if (orderError) throw orderError;

      // Refresh the orders list
      await fetchOrders();
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

<Navbar 
  bind:cartButton
  onCartToggle={toggleCart} 
  onMenuToggle={toggleMenu}
  onLogoClick={() => goto('/')}
/>

<main class="orders-container">
  <h1>Your Orders</h1>

  {#if error}
    <div class="error-message">{error}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading your orders...</div>
  {:else if orders.length === 0}
    <div class="empty-state">
      <p>You haven't placed any orders yet.</p>
      <a href="/" class="shop-now-btn">Start Shopping</a>
    </div>
  {:else}
    <div class="orders-list">
      {#each orders as order (order.id)}
        <div class="order-card">
          <div class="order-header">
            <div class="order-info">
              <h3>Order #{order.id}</h3>
              <p class="order-date">{formatDate(order.created_at)}</p>
            </div>
          </div>

          <div class="order-items">
            {#each order.order_items as item}
              <div class="order-item">
                <img src={item.product.image_url} alt={item.product.name} />
                <div class="item-details">
                  <h4>{item.product.name}</h4>
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
              <span>R{calculateTotal(order.order_items)}</span>
            </div>
            <div class="order-actions">
              <button class="reorder-btn" on:click={() => goto('/')}>
                Reorder
              </button>
              <button 
                class="delete-btn" 
                on:click={() => deleteOrder(order.id)}
                aria-label="Delete order"
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

<style>
  .orders-container {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1rem;
  }

  h1 {
    text-align: center;
    margin-bottom: 2rem;
    color: #333;
  }

  .orders-list {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .order-card {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
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
    color: #333;
    font-size: 1.2rem;
  }

  .order-date {
    color: #666;
    font-size: 0.9rem;
    margin: 0.25rem 0 0;
  }

  .order-status {
    padding: 0.5rem 1rem;
    border-radius: 20px;
    font-size: 0.9rem;
    font-weight: 500;
  }

  .order-status.pending {
    background: #fff3cd;
    color: #856404;
  }

  .order-status.processing {
    background: #cce5ff;
    color: #004085;
  }

  .order-status.delivered {
    background: #d4edda;
    color: #155724;
  }

  .order-status.cancelled {
    background: #f8d7da;
    color: #721c24;
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

  @media (max-width: 768px) {
    .order-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }

    .order-status {
      align-self: flex-start;
    }

    .order-item {
      flex-direction: column;
      text-align: center;
    }

    .item-details {
      text-align: center;
    }

    .order-footer {
      flex-direction: column;
      gap: 1rem;
      text-align: center;
    }

    .reorder-btn {
      width: 100%;
    }
  }
</style> 