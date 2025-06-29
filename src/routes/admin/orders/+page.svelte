<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabase';
  import AdminNav from '$lib/components/AdminNav.svelte';
  import OrderDetailsModal from '$lib/components/OrderDetailsModal.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import type { Order, OrderStatus } from '$lib/types/orders';
  import { formatCurrency } from '$lib/services/settingsService';

  let orders: Order[] = [];
  let filteredOrders: Order[] = [];
  let loading = true;
  let selectedOrder: Order | null = null;
  let showOrderModal = false;
  let showDeleteConfirm = false;
  let orderToDelete: Order | null = null;
  let error: string | null = null;

  // Filter states
  let statusFilter = 'all';
  let searchTerm = '';
  let dateFrom = '';
  let dateTo = '';

  // Financial summary
  let financialSummary = {
    totalOrders: 0,
    totalRevenue: 0,
    averageOrder: 0,
    completedOrders: 0,
    completedRevenue: 0,
    pendingOrders: 0,
    pendingRevenue: 0,
    guestOrders: 0,
    registeredOrders: 0
  };

  async function loadOrders() {
    loading = true;
    try {
      let query = supabase.from('orders').select(`
        *,
        order_items (
          id,
          quantity,
          price,
          products (id, name, image_url)
        ),
        user:profiles!orders_user_id_fkey (
          auth_user_id,
          display_name,
          email,
          phone_number,
          address
        )
      `).order('created_at', { ascending: false });

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }
      if (dateFrom) {
        query = query.gte('created_at', new Date(dateFrom).toISOString());
      }
      if (dateTo) {
        query = query.lte('created_at', new Date(dateTo + 'T23:59:59').toISOString());
      }

      const { data, error: fetchError } = await query;
      if (fetchError) throw fetchError;
      orders = data || [];
      // For search, filter client-side for now
      if (searchTerm) {
        const term = searchTerm.toLowerCase();
        filteredOrders = orders.filter(order => 
          order.id.toLowerCase().includes(term) ||
          order.user?.email?.toLowerCase().includes(term) ||
          order.user?.display_name?.toLowerCase().includes(term) ||
          order.guest_info?.email?.toLowerCase().includes(term) ||
          order.guest_info?.name?.toLowerCase().includes(term)
        );
      } else {
        filteredOrders = orders;
      }
    } catch (err: any) {
      console.error('Error loading orders:', err);
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function loadFinancialSummary() {
    try {
      // Optionally, you can pass dateFrom/dateTo/status filters here
      const { data, error } = await supabase.rpc('get_order_summary', {
        p_start_date: dateFrom ? new Date(dateFrom).toISOString() : null,
        p_end_date: dateTo ? new Date(dateTo + 'T23:59:59').toISOString() : null,
        p_status: statusFilter !== 'all' ? statusFilter : null
      });
      if (error) throw error;
      const summary = Array.isArray(data) ? data[0] : data;
      console.log('order summary:', data, summary);
      if (!summary) {
        financialSummary = {
          totalOrders: 0,
          totalRevenue: 0,
          averageOrder: 0,
          completedOrders: 0,
          completedRevenue: 0,
          pendingOrders: 0,
          pendingRevenue: 0,
          guestOrders: 0,
          registeredOrders: 0
        };
      } else {
        financialSummary = {
          totalOrders: summary.total_orders ?? 0,
          totalRevenue: summary.total_revenue ?? 0,
          averageOrder: summary.average_order_value ?? 0,
          completedOrders: summary.completed_orders ?? 0,
          completedRevenue: summary.completed_revenue ?? 0,
          pendingOrders: summary.pending_orders ?? 0,
          pendingRevenue: summary.pending_revenue ?? 0,
          guestOrders: summary.guest_orders ?? 0,
          registeredOrders: summary.registered_orders ?? 0
        };
      }
    } catch (err) {
      console.error('Error loading financial summary:', err);
    }
  }

  $: [dateFrom, dateTo, statusFilter, searchTerm], loadOrders();
  $: [dateFrom, dateTo, statusFilter], loadFinancialSummary();

  async function handleOrderDelete() {
    if (!orderToDelete) return;
    
    try {
      const { error: deleteError } = await supabase
        .from('orders')
        .delete()
        .eq('id', orderToDelete.id);

      if (deleteError) throw deleteError;
      
      await loadOrders();
      showDeleteConfirm = false;
      orderToDelete = null;
    } catch (err: any) {
      console.error('Error deleting order:', err);
      error = err.message;
    }
  }

  function handleOrderStatusUpdate(orderId: string, newStatus: OrderStatus) {
    const orderIndex = orders.findIndex(o => o.id === orderId);
    if (orderIndex !== -1) {
      orders[orderIndex] = { ...orders[orderIndex], status: newStatus };
      loadOrders();
    }
    showOrderModal = false;
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

  function getStatusBadgeClass(status: string) {
    switch (status) {
      case 'completed': return 'badge-success';
      case 'processing': return 'badge-warning';
      case 'pending': return 'badge-info';
      case 'cancelled': return 'badge-danger';
      default: return 'badge-primary';
    }
  }
</script>

<StarryBackground />
<AdminNav />

<main class="admin-main">
  <div class="admin-container">
    <div class="admin-header">
      <h1 class="neon-text-cyan">Order Management</h1>
    </div>

    {#if error}
      <div class="alert alert-danger">
        {error}
      </div>
    {/if}

    <!-- Filters Section -->
    <div class="glass mb-4">
      <div class="card-body">
        <div class="admin-grid admin-grid-4">
          <div class="form-group">
            <label class="form-label">Status</label>
            <select bind:value={statusFilter} class="form-control form-select">
              <option value="all">All</option>
              <option value="pending">Pending</option>
              <option value="processing">Processing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          
          <div class="form-group">
            <label class="form-label">From</label>
            <input type="date" bind:value={dateFrom} class="form-control" />
          </div>
          
          <div class="form-group">
            <label class="form-label">To</label>
            <input type="date" bind:value={dateTo} class="form-control" />
          </div>
          
          <div class="form-group">
            <label class="form-label">Search</label>
            <input 
              type="text" 
              bind:value={searchTerm} 
              placeholder="Search..." 
              class="form-control" 
            />
          </div>
        </div>
      </div>
    </div>

    {#if loading}
      <div class="text-center p-4">
        <div class="spinner-large"></div>
        <p class="neon-text-cyan mt-2">Loading orders...</p>
      </div>
    {:else}
      <!-- Orders Table -->
      <div class="glass mb-4">
        <!-- Desktop Table View -->
        <div class="table-responsive desktop-only">
          <table class="table-dark">
            <thead>
              <tr>
                <th>Order #</th>
                <th>Date</th>
                <th>Customer</th>
                <th>Email</th>
                <th>Type</th>
                <th>Payment</th>
                <th>Total</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {#each filteredOrders as order (order.id)}
                <tr class="hover-glow">
                  <td class="neon-text-white">
                    {order.order_number || order.id.substring(0, 8)}
                  </td>
                  <td>{formatDate(order.created_at)}</td>
                  <td>
                    {#if order.user}
                      {order.user.display_name || 'N/A'}
                    {:else if order.guest_info}
                      {order.guest_info.name || 'Guest'}
                    {:else}
                      Unknown
                    {/if}
                  </td>
                  <td>
                    {#if order.user}
                      {order.user.email || 'N/A'}
                    {:else if order.guest_info}
                      {order.guest_info.email || 'N/A'}
                    {:else}
                      N/A
                    {/if}
                  </td>
                  <td>
                    <span class="badge {order.user ? 'badge-info' : 'badge-warning'}">
                      {order.user ? 'Registered' : 'Guest'}
                    </span>
                  </td>
                  <td>{order.payment_method || 'cash'}</td>
                  <td class="neon-text-cyan">
                    {formatCurrency(Number(order.total) || 0)}
                  </td>
                  <td>
                    <span class="badge {getStatusBadgeClass(order.status)}">
                      {order.status}
                    </span>
                  </td>
                  <td>
                    <div class="flex gap-1">
                      <button 
                        class="btn btn-secondary btn-sm"
                        on:click={() => { selectedOrder = order; showOrderModal = true; }}
                      >
                        Details
                      </button>
                      <button 
                        class="btn btn-danger btn-sm"
                        on:click={() => { orderToDelete = order; showDeleteConfirm = true; }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <!-- Mobile Card View -->
        <div class="admin-grid mobile-only">
          {#each filteredOrders as order (order.id)}
            <div class="admin-card">
              <div class="admin-card-header">
                <div>
                  <div class="admin-card-title">Order #{order.order_number || order.id.substring(0, 8)}</div>
                  <div class="admin-card-subtitle">{formatDate(order.created_at)}</div>
                </div>
                <div class="badge-group">
                  <span class="badge {order.user ? 'badge-info' : 'badge-warning'}">
                    {order.user ? 'Registered' : 'Guest'}
                  </span>
                  <span class="badge {getStatusBadgeClass(order.status)}">
                    {order.status}
                  </span>
                </div>
              </div>
              
              <div class="admin-card-body">
                <div class="admin-card-row">
                  <span class="admin-card-label">Customer:</span>
                  <span class="admin-card-value">
                    {#if order.user}
                      {order.user.display_name || 'N/A'}
                    {:else if order.guest_info}
                      {order.guest_info.name || 'Guest'}
                    {:else}
                      Unknown
                    {/if}
                  </span>
                </div>
                
                <div class="admin-card-row">
                  <span class="admin-card-label">Email:</span>
                  <span class="admin-card-value">
                    {#if order.user}
                      {order.user.email || 'N/A'}
                    {:else if order.guest_info}
                      {order.guest_info.email || 'N/A'}
                    {:else}
                      N/A
                    {/if}
                  </span>
                </div>
                
                <div class="admin-card-row">
                  <span class="admin-card-label">Payment:</span>
                  <span class="admin-card-value">{order.payment_method || 'cash'}</span>
                </div>
                
                <div class="admin-card-row">
                  <span class="admin-card-label">Total:</span>
                  <span class="admin-card-value neon-text-cyan">
                    {formatCurrency(Number(order.total) || 0)}
                  </span>
                </div>
              </div>
              
              <div class="admin-card-actions">
                <button 
                  class="btn btn-secondary btn-sm"
                  on:click={() => { selectedOrder = order; showOrderModal = true; }}
                >
                  Details
                </button>
                <button 
                  class="btn btn-danger btn-sm"
                  on:click={() => { orderToDelete = order; showDeleteConfirm = true; }}
                >
                  Delete
                </button>
              </div>
            </div>
          {/each}
        </div>

        {#if filteredOrders.length === 0}
          <div class="text-center p-4">
            <p class="neon-text-cyan">No orders found.</p>
          </div>
        {/if}
      </div>

      <!-- Financial Summary -->
      <div class="glass">
        <div class="card-header">
          <h3 class="neon-text-cyan">Financial Summary ({filteredOrders.length} orders)</h3>
        </div>
        <div class="card-body">
          <div class="admin-grid admin-grid-4">
            <div class="summary-card glass-light">
              <h4 class="neon-text-white">Total Revenue</h4>
              <p class="neon-text-cyan text-2xl font-bold">
                {formatCurrency(financialSummary.totalRevenue)}
              </p>
            </div>
            
            <div class="summary-card glass-light">
              <h4 class="neon-text-white">Average Order</h4>
              <p class="neon-text-cyan text-2xl font-bold">
                {formatCurrency(financialSummary.averageOrder)}
              </p>
            </div>
            
            <div class="summary-card glass-light">
              <h4 class="text-green-400">Completed</h4>
              <p class="text-green-400 font-bold">
                {financialSummary.completedOrders} orders
              </p>
              <p class="text-green-400 text-lg font-bold">
                {formatCurrency(financialSummary.completedRevenue)}
              </p>
            </div>
            
            <div class="summary-card glass-light">
              <h4 class="text-yellow-400">Pending</h4>
              <p class="text-yellow-400 font-bold">
                {financialSummary.pendingOrders} orders
              </p>
              <p class="text-yellow-400 text-lg font-bold">
                {formatCurrency(financialSummary.pendingRevenue)}
              </p>
            </div>
            
            <div class="summary-card glass-light">
              <h4 class="neon-text-white">Customer Types</h4>
              <p class="text-sm">
                <span class="neon-text-cyan">{financialSummary.guestOrders} guest</span><br>
                <span class="neon-text-cyan">{financialSummary.registeredOrders} registered</span>
              </p>
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</main>

{#if showOrderModal && selectedOrder}
  <OrderDetailsModal 
    order={selectedOrder}
    onClose={() => showOrderModal = false}
    onStatusUpdate={handleOrderStatusUpdate}
  />
{/if}

{#if showDeleteConfirm}
  <ConfirmModal
    message="Are you sure you want to delete this order? This action cannot be undone."
    onConfirm={handleOrderDelete}
    onCancel={() => { showDeleteConfirm = false; orderToDelete = null; }}
  />
{/if}

<style>
  .admin-main {
    min-height: 100vh;
    padding-top: 80px;
    background: transparent;
  }

  .admin-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
    margin-top: 6pc;
  }

  .admin-header {
    margin-bottom: 2rem;
    text-align: center;
  }

  .admin-header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    letter-spacing: 1px;
  }

  .summary-card {
    padding: 1.5rem;
    border-radius: 8px;
    text-align: center;
    transition: var(--transition-fast);
  }

  .summary-card:hover {
    border-color: var(--neon-cyan);
    box-shadow: var(--shadow-neon-cyan);
  }

  .summary-card h4 {
    font-size: 0.9rem;
    font-weight: 600;
    margin: 0 0 0.5rem 0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .summary-card p {
    margin: 0;
  }

  .text-2xl {
    font-size: 1.5rem;
  }

  .text-lg {
    font-size: 1.125rem;
  }

  .text-sm {
    font-size: 0.875rem;
  }

  .font-bold {
    font-weight: 700;
  }

  .text-green-400 {
    color: #4ade80;
  }

  .text-yellow-400 {
    color: #facc15;
  }



  @media (max-width: 1200px) {
    .admin-container {
      padding: 1rem;
    }
    
    .admin-header h1 {
      font-size: 2rem;
    }
  }

  @media (max-width: 768px) {
    .table-dark {
      font-size: 0.8rem;
    }
    
    .summary-card {
      padding: 1rem;
    }
    
    .summary-card h4 {
      font-size: 0.8rem;
    }
    
    .text-2xl {
      font-size: 1.25rem;
    }
  }
</style> 