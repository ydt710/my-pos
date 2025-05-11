<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import type { Order, OrderStatus } from '$lib/types/orders';
  import { fade } from 'svelte/transition';
  import OrderDetailsModal from '$lib/components/OrderDetailsModal.svelte';

  let orders: Order[] = [];
  let loading = true;
  let error: string | null = null;
  let selectedOrder: Order | null = null;
  let showModal = false;

  let filters = {
    status: '' as OrderStatus | '',
    dateFrom: '',
    dateTo: '',
    search: ''
  };

  const orderStatuses: OrderStatus[] = ['pending', 'processing', 'completed', 'cancelled'];

  onMount(() => {
    fetchOrders();
  });

  async function fetchOrders() {
    loading = true;
    error = null;
    try {
      let query = supabase
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
          ),
          user:profiles (
            email,
            user_metadata
          )
        `)
        .order('created_at', { ascending: false });

      // Apply filters
      if (filters.status) {
        query = query.eq('status', filters.status);
      }
      if (filters.dateFrom) {
        query = query.gte('created_at', filters.dateFrom);
      }
      if (filters.dateTo) {
        query = query.lte('created_at', filters.dateTo);
      }
      if (filters.search) {
        query = query.or(`id.eq.${filters.search},user.email.ilike.%${filters.search}%`);
      }

      const { data, error: err } = await query;
      
      if (err) throw err;
      orders = data;
    } catch (err) {
      console.error('Error fetching orders:', err);
      error = 'Failed to load orders';
    } finally {
      loading = false;
    }
  }

  async function updateOrderStatus(orderId: string, newStatus: OrderStatus) {
    try {
      const { error: err } = await supabase
        .from('orders')
        .update({ status: newStatus })
        .eq('id', orderId);

      if (err) throw err;
      await fetchOrders();
    } catch (err) {
      console.error('Error updating order status:', err);
      error = 'Failed to update order status';
    }
  }

  function viewOrderDetails(order: Order) {
    selectedOrder = order;
    showModal = true;
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function getStatusColor(status: OrderStatus) {
    const colors: Record<OrderStatus, string> = {
      pending: '#ffc107',
      processing: '#17a2b8',
      completed: '#28a745',
      cancelled: '#dc3545'
    };
    return colors[status];
  }

  $: {
    // Reactively fetch orders when filters change
    if (!loading) {
      fetchOrders();
    }
  }
</script>

<div class="orders-page" in:fade>
  <header class="page-header">
    <h1>Orders</h1>
    <div class="filters">
      <select 
        bind:value={filters.status}
        class="filter-select"
      >
        <option value="">All Statuses</option>
        {#each orderStatuses as status}
          <option value={status}>{status}</option>
        {/each}
      </select>

      <input 
        type="date" 
        bind:value={filters.dateFrom}
        class="filter-date"
        placeholder="From Date"
      />

      <input 
        type="date" 
        bind:value={filters.dateTo}
        class="filter-date"
        placeholder="To Date"
      />

      <input 
        type="text" 
        bind:value={filters.search}
        class="filter-search"
        placeholder="Search order ID or email"
      />
    </div>
  </header>

  {#if error}
    <div class="alert error" role="alert">{error}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading orders...</div>
  {:else if orders.length === 0}
    <div class="no-orders">No orders found</div>
  {:else}
    <div class="orders-table-container">
      <table class="orders-table">
        <thead>
          <tr>
            <th>Order ID</th>
            <th>Date</th>
            <th>Customer</th>
            <th>Total</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each orders as order (order.id)}
            <tr>
              <td>#{order.order_number}</td>
              <td>{formatDate(order.created_at)}</td>
              <td>
                {order.user?.user_metadata?.name || order.user?.email || order.guest_info?.name || 'Unknown'}
              </td>
              <td>R{order.total}</td>
              <td>
                <div class="status-cell">
                  <span 
                    class="status-badge"
                    style="background-color: {getStatusColor(order.status)}"
                  >
                    {order.status}
                  </span>
                  <select 
                    value={order.status}
                    on:change={(e) => {
                      const target = e.target as HTMLSelectElement;
                      updateOrderStatus(order.id, target.value as OrderStatus);
                    }}
                    class="status-select"
                  >
                    {#each orderStatuses as status}
                      <option value={status}>{status}</option>
                    {/each}
                  </select>
                </div>
              </td>
              <td>
                <button 
                  class="view-btn"
                  on:click={() => viewOrderDetails(order)}
                >
                  View Details
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

{#if showModal && selectedOrder}
  <OrderDetailsModal 
    order={selectedOrder}
    onClose={() => {
      showModal = false;
      selectedOrder = null;
    }}
    onStatusUpdate={updateOrderStatus}
  />
{/if}

<style>
  .orders-page {
    padding: 1rem;
  }

  .page-header {
    margin-bottom: 2rem;
  }

  h1 {
    margin: 0 0 1rem;
    font-size: 2rem;
    color: #333;
  }

  .filters {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .filter-select,
  .filter-date,
  .filter-search {
    padding: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 1rem;
  }

  .filter-search {
    min-width: 200px;
  }

  .alert {
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
  }

  .alert.error {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
  }

  .orders-table-container {
    overflow-x: auto;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }

  .orders-table {
    width: 100%;
    border-collapse: collapse;
    min-width: 800px;
  }

  th, td {
    padding: 1rem;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  th {
    background: #f8f9fa;
    font-weight: 600;
    color: #333;
  }

  .status-cell {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .status-badge {
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    color: white;
    font-size: 0.875rem;
    text-transform: capitalize;
  }

  .status-select {
    padding: 0.25rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    background: white;
  }

  .view-btn {
    background: #007bff;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .view-btn:hover {
    background: #0056b3;
  }

  .loading,
  .no-orders {
    text-align: center;
    padding: 2rem;
    color: #666;
  }

  @media (max-width: 768px) {
    .filters {
      flex-direction: column;
    }

    .filter-select,
    .filter-date,
    .filter-search {
      width: 100%;
    }
  }
</style> 