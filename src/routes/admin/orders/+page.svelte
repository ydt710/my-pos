<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import type { Order, OrderStatus, OrderFilters } from '$lib/types/orders';
  import { getAllOrders, updateOrderStatus, reapplyOrderStock } from '$lib/services/orderService';
  import { fade } from 'svelte/transition';
  import OrderDetailsModal from '$lib/components/OrderDetailsModal.svelte';
  import { showSnackbar } from '$lib/stores/snackbarStore';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';

  let orders: Order[] = [];
  let loadingOrders = true;
  let orderError: string | null = null;
  let selectedOrder: Order | null = null;

  let filters: OrderFilters = {
    status: undefined,
    dateFrom: undefined,
    dateTo: undefined,
    search: '',
    sortBy: 'created_at',
    sortOrder: 'desc'
  };

  let showConfirmModal = false;
  let orderIdToDelete: string | null = null;
  
  let showCancelConfirm = false;
  let orderIdToCancel: string | null = null;

  onMount(() => {
    loadOrders();
  });

  async function loadOrders() {
    loadingOrders = true;
    orderError = null;
    const { orders: fetchedOrders, error } = await getAllOrders(filters);
    if (error) {
      orderError = error;
    } else {
      orders = fetchedOrders;
    }
    loadingOrders = false;
  }

  async function handleStatusUpdate(orderId: string, newStatus: OrderStatus) {
    if (newStatus === 'cancelled') {
      showCancelConfirm = true;
      orderIdToCancel = orderId;
      return;
    }
    const { success, error } = await updateOrderStatus(orderId, newStatus);
    if (success) {
      await loadOrders();
      if (selectedOrder?.id === orderId) {
        selectedOrder.status = newStatus;
      }
    } else {
      orderError = error;
    }
  }
  
  async function confirmCancelOrder() {
    if (!orderIdToCancel) return;
    const { success: stockSuccess, error: stockError } = await reapplyOrderStock(orderIdToCancel);
    if (!stockSuccess) {
      orderError = stockError || 'Failed to reapply stock.';
      showCancelConfirm = false;
      orderIdToCancel = null;
      return;
    }
    const { success, error } = await updateOrderStatus(orderIdToCancel, 'cancelled');
    if (success) {
      await loadOrders();
      if (selectedOrder?.id === orderIdToCancel) {
        selectedOrder.status = 'cancelled';
      }
    } else {
      orderError = error;
    }
    showCancelConfirm = false;
    orderIdToCancel = null;
  }

  function cancelCancelOrder() {
    showCancelConfirm = false;
    orderIdToCancel = null;
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleString();
  }

  function getCustomerInfo(order: Order) {
    if (order.guest_info) {
      return { name: order.guest_info.name, email: order.guest_info.email };
    } else if (order.user) {
      const name = 'display_name' in order.user && order.user.display_name ? order.user.display_name : order.user.email?.split('@')[0] || 'N/A';
      return { name, email: order.user.email || 'N/A' };
    }
    return { name: 'N/A', email: 'N/A' };
  }
  
  async function deleteOrder(orderId: string) {
    loadingOrders = true;
    orderError = null;
    try {
      await supabase.from('order_items').delete().eq('order_id', orderId);
      await supabase.from('orders').delete().eq('id', orderId);
      orders = orders.filter(o => o.id !== orderId);
      showSnackbar('Order deleted successfully.');
      loadOrders();
    } catch (err) {
      orderError = 'Failed to delete order.';
      showSnackbar(orderError);
    } finally {
      loadingOrders = false;
    }
  }

  $: if (filters) {
    loadOrders();
  }
</script>

<div class="orders-page" in:fade>
  <header class="page-header">
    <h1>Order Management</h1>
  </header>

  {#if orderError}
    <div class="alert error" transition:fade>{orderError}</div>
  {/if}
  
  <div class="filters-card">
    <div class="filters">
      <div class="filter-group"><label for="status">Status</label><select id="status" bind:value={filters.status}><option value={undefined}>All</option><option value="pending">Pending</option><option value="processing">Processing</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option></select></div>
      <div class="filter-group"><label for="dateFrom">From</label><input type="date" id="dateFrom" bind:value={filters.dateFrom} /></div>
      <div class="filter-group"><label for="dateTo">To</label><input type="date" id="dateTo" bind:value={filters.dateTo} /></div>
      <div class="filter-group"><label for="search">Search</label><input type="text" id="search" placeholder="Search..." bind:value={filters.search} /></div>
    </div>
  </div>
  
  {#if loadingOrders}
    <div class="loading">Loading orders...</div>
  {:else}
    <div class="table-card">
      <div class="table-responsive desktop-only">
        <table>
          <thead><tr><th>Order #</th><th>Date</th><th>Customer</th><th>Email</th><th>Type</th><th>Payment</th><th>Total</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {#each orders as order (order.id)}
              <tr class:guest-order={order.guest_info}>
                <td>{order.order_number || order.id}</td>
                <td>{formatDate(order.created_at)}</td>
                <td><strong>{getCustomerInfo(order).name}</strong></td>
                <td>{getCustomerInfo(order).email}</td>
                <td>{#if order.guest_info}<span class="badge guest">Guest</span>{:else}<span class="badge registered">Registered</span>{/if}</td>
                <td>{order.payment_method || '-'}</td>
                <td>R{order.total}</td>
                <td><select value={order.status} class="status-select" on:change={(e) => handleStatusUpdate(order.id, e.currentTarget.value as OrderStatus)} disabled={order.status === 'cancelled'}><option value="pending">Pending</option><option value="processing">Processing</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option></select></td>
                <td><button class="view-details-btn" on:click={() => selectedOrder = order}>Details</button><button class="delete-btn" on:click={() => { showConfirmModal = true; orderIdToDelete = order.id; }}>Delete</button></td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <div class="mobile-cards mobile-only">
        {#each orders as order (order.id)}
          <div class="admin-card">
            <!-- Mobile card view can be implemented here if needed -->
          </div>
        {/each}
      </div>
    </div>
  {/if}
</div>

{#if selectedOrder}
    <OrderDetailsModal order={selectedOrder} onClose={() => selectedOrder = null} onStatusUpdate={handleStatusUpdate} />
{/if}

{#if showConfirmModal}
    <ConfirmModal message="Delete this order?" onConfirm={() => { if (orderIdToDelete) deleteOrder(orderIdToDelete); showConfirmModal = false; orderIdToDelete = null; }} onCancel={() => { showConfirmModal = false; orderIdToDelete = null; }} />
{/if}

{#if showCancelConfirm}
  <div class="modal-backdrop">
    <div class="modal-content" style="max-width: 500px;">
      <div class="modal-header">
        <h2>Cancel Order?</h2>
      </div>
      <div class="modal-body">
        <p>This will reapply stock to inventory. Are you sure?</p>
      </div>
      <div class="modal-actions">
        <button class="btn" on:click={cancelCancelOrder}>No</button>
        <button class="btn danger" on:click={confirmCancelOrder}>Yes, cancel</button>
      </div>
    </div>
  </div>
{/if}


<style>
  /* Styles extracted and simplified from admin/+page.svelte */
  .orders-page { padding: 1rem; max-width: 1400px; margin: 0 auto; }
  .page-header { margin-bottom: 2rem; }
  h1 { font-size: 2rem; }
  .filters-card, .table-card { background: white; padding: 1.5rem; border-radius: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); margin-bottom: 1.5rem; }
  .filters { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; }
  .filter-group { display: flex; flex-direction: column; gap: 0.5rem; }
  label { font-size: 0.9rem; color: #666; }
  input, select { padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; }
  .table-responsive { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; min-width: 800px; }
  th, td { padding: 1rem; text-align: left; border-bottom: 1px solid #e9ecef; }
  th { background: #f8f9fa; }
  .view-details-btn, .delete-btn { padding: 0.5rem 1rem; border: none; border-radius: 4px; cursor: pointer; }
  .view-details-btn { background: #28a745; color: white; }
  .delete-btn { background: #dc3545; color: white; margin-left: 0.5rem; }
  .badge { padding: .25em .6em; font-size: 75%; font-weight: 700; line-height: 1; text-align: center; white-space: nowrap; vertical-align: baseline; border-radius: .25rem; }
  .badge.guest { color: #fff; background-color: #6c757d; }
  .badge.registered { color: #fff; background-color: #17a2b8; }
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1000;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  .modal-content {
    background: white;
    padding: 0;
    border-radius: 12px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.3);
    display: flex;
    flex-direction: column;
  }
  .modal-header {
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e9ecef;
  }
  .modal-header h2 {
    margin: 0;
    font-size: 1.25rem;
  }
  .modal-body {
    padding: 1.5rem;
  }
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    padding: 1rem 1.5rem;
    border-top: 1px solid #e9ecef;
    background-color: #f8f9fa;
  }
  .btn {
    padding: 0.5rem 1rem;
    border-radius: 4px;
    border: 1px solid #ddd;
    background-color: #f8f9fa;
    cursor: pointer;
  }
  .btn.danger {
    background-color: #dc3545;
    color: white;
    border-color: #dc3545;
  }
</style> 