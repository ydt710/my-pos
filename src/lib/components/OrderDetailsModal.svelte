<script lang="ts">
  import { fade, scale } from 'svelte/transition';
  import type { Order, OrderStatus } from '$lib/types/orders';
  import { updateOrderStatus, reapplyOrderStock } from '$lib/services/orderService';
  import { supabase } from '$lib/supabase';
  import { getUserBalance, getUserAvailableCredit } from '$lib/services/orderService';
  import { onMount } from 'svelte';
  import type { Transaction } from '$lib/types/ledger';

  export let order: Order;
  export let onClose: () => void;
  export let onStatusUpdate: (orderId: string, status: OrderStatus) => void;

  let loading = false;
  let error: string | null = null;
  let ledgerEntries: Transaction[] = [];
  let loadingLedger = false;
  let userBalance: number | null = null;
  let userDebtAtOrderTime: number | null = null;
  const FLOAT_USER_ID = 'ab54f66c-fa1c-40d2-ad2a-d9d5c1603e0f';
  // @ts-ignore
  let html2pdf: any = null;
  let showCancelConfirm = false;

  // Calculate subtotal from items if not present on order
  $: subtotal = order.subtotal ?? (order.order_items || []).reduce((sum, item) => sum + item.price * item.quantity, 0);
  $: tax = order.tax ?? 0; // Assuming tax is not easily calculated from items here
  $: shipping_fee = order.shipping_fee ?? 0; // Assuming shipping is not in items

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleString();
  }

  function formatCurrency(amount: number) {
    return `R${(amount ?? 0).toFixed(2)}`;
  }

  async function handleStatusChange(event: Event) {
    const select = event.target as HTMLSelectElement;
    const newStatus = select.value as OrderStatus;
    if (newStatus === 'cancelled') {
      showCancelConfirm = true;
      return;
    }
    update(newStatus);
  }
  
  async function confirmCancel() {
    showCancelConfirm = false;
    loading = true;
    error = null;
    const { success: stockSuccess, error: stockError } = await reapplyOrderStock(order.id);
    if (!stockSuccess) {
      error = stockError || 'Failed to reapply stock.';
      loading = false;
      return;
    }
    await update('cancelled');
    loading = false;
  }

  async function update(newStatus: OrderStatus) {
    loading = true;
    error = null;
    const { success, error: updateError } = await updateOrderStatus(order.id, newStatus);
    if (success) {
      onStatusUpdate(order.id, newStatus);
    } else {
      error = updateError;
    }
    loading = false;
  }

  function getCustomerInfo() {
    if (order.guest_info) return { ...order.guest_info, type: 'Guest' };
    if (order.user) return { name: order.user.display_name, email: order.user.email, phone: order.user.phone_number, address: order.user.address, type: 'Registered' };
    return { name: 'N/A', email: 'N/A', phone: 'N/A', address: 'N/A', type: 'Unknown' };
  }
  
  $: customer = getCustomerInfo();
  
  $: if (order && order.user_id) {
    getUserBalance(order.user_id).then(b => userBalance = b);
  }

  onMount(async () => {
    if (typeof window !== 'undefined') {
      html2pdf = (await import('html2pdf.js')).default;
    }
    if(order.id) {
      loadingLedger = true;
      const { data } = await supabase.from('transactions').select('*').eq('order_id', order.id);
      ledgerEntries = data || [];
      loadingLedger = false;
    }
  });

  async function exportToPDF() {
    const element = document.getElementById('modal-body-content');
    if (!element) return;
    const opt = {
      margin: 0.5,
      filename: `order_${order.order_number || order.id}.pdf`,
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 2, useCORS: true },
      jsPDF: { unit: 'in', format: 'letter', orientation: 'portrait' }
    };
    await html2pdf().from(element).set(opt).save();
  }
</script>

<div class="modal-backdrop" on:click={onClose} on:keydown={(e) => e.key === 'Escape' && onClose()} role="dialog" aria-labelledby="modal-title" tabindex="-1">
  <div class="modal-content" on:click|stopPropagation role="document" transition:scale={{ duration: 250, start: 0.95 }}>
    <div class="modal-header">
      <h2 id="modal-title">Order #{order.order_number || order.id}</h2>
      <div>
        <button class="icon-btn" on:click={exportToPDF} title="Export to PDF">🖨️</button>
        <button class="close-btn" on:click={onClose} aria-label="Close">&times;</button>
      </div>
    </div>
    
    <div class="modal-body" id="modal-body-content">
      {#if error}
        <div class="alert error">{error}</div>
      {/if}

      <div class="grid-container">
        <section class="info-card customer-info">
          <h3>Customer Details</h3>
          <p><strong>{customer.name}</strong> ({customer.type})</p>
          <p>{customer.email}</p>
          <p>{customer.phone}</p>
          <p>{customer.address}</p>
        </section>

        <section class="info-card order-summary">
          <h3>Order Summary</h3>
          <p><strong>Date:</strong> {formatDate(order.created_at)}</p>
          <p><strong>Payment:</strong> {order.payment_method}</p>
          <div class="status-control">
            <strong>Status:</strong>
            <select value={order.status} on:change={handleStatusChange} disabled={loading || order.status === 'cancelled'}>
              <option value="pending">Pending</option>
              <option value="processing">Processing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
        </section>
      </div>

      <section class="info-card items-list">
        <h3>Items Ordered ({order.order_items?.length})</h3>
        <div class="table-wrapper">
          <table>
            <thead><tr><th>Product</th><th>Quantity</th><th>Price</th><th>Total</th></tr></thead>
            <tbody>
              {#each order.order_items || [] as item}
                <tr>
                  <td>{item.products?.name || 'Product not found'}</td>
                  <td>{item.quantity}</td>
                  <td>{formatCurrency(item.price)}</td>
                  <td>{formatCurrency(item.price * item.quantity)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </section>

      <div class="grid-container">
        <section class="info-card financial-summary">
          <h3>Financials</h3>
          <div class="financial-grid">
            <div>Subtotal:</div><div>{formatCurrency(subtotal)}</div>
            <div>Tax:</div><div>{formatCurrency(tax)}</div>
            <div>Shipping:</div><div>{formatCurrency(shipping_fee)}</div>
            <div class="total">Total:</div><div class="total">{formatCurrency(order.total)}</div>
          </div>
        </section>

        <section class="info-card ledger-info">
          <h3>Ledger Info</h3>
          {#if loadingLedger}
            <p>Loading ledger...</p>
          {:else}
            {#each ledgerEntries as entry}
              <p>{entry.type}: {formatCurrency(entry.amount)}</p>
            {/each}
            {#if customer.type !== 'Guest' && userBalance !== null}
              <p><strong>User Balance:</strong> {formatCurrency(userBalance)}</p>
            {/if}
          {/if}
        </section>
      </div>
    </div>
  </div>
</div>

{#if showCancelConfirm}
  <div class="modal-backdrop confirm-modal-backdrop">
    <div class="modal-content confirm-modal-content">
      <h3>Confirm Cancellation</h3>
      <p>This will permanently cancel the order and restock items. Are you sure?</p>
      <div class="modal-actions">
        <button class="btn" on:click={() => showCancelConfirm = false}>Back</button>
        <button class="btn danger" on:click={confirmCancel}>Yes, Cancel</button>
      </div>
    </div>
  </div>
{/if}

<style>
  :root {
    --modal-max-width: 800px;
    --modal-padding: 1.5rem;
    --card-bg: #ffffff;
    --card-border-radius: 8px;
    --card-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }
  .modal-backdrop {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.6);
    z-index: 1000;
    display: flex; justify-content: center; align-items: center;
  }
  .modal-content {
    background: #f4f5f7;
    border-radius: var(--card-border-radius);
    box-shadow: 0 5px 15px rgba(0,0,0,0.3);
    max-width: var(--modal-max-width);
    width: 90vw;
    max-height: 90vh;
    display: flex; flex-direction: column;
    overflow: hidden;
  }
  .modal-header {
    display: flex; justify-content: space-between; align-items: center;
    padding: 1rem var(--modal-padding);
    background: var(--card-bg);
    border-bottom: 1px solid #e9ecef;
  }
  .modal-header h2 { margin: 0; font-size: 1.25rem; }
  .icon-btn, .close-btn {
    background: none; border: none; font-size: 1.5rem; cursor: pointer;
    color: #6c757d; transition: color 0.2s;
  }
  .icon-btn:hover, .close-btn:hover { color: #343a40; }
  .close-btn { line-height: 1; padding: 0; }
  
  .modal-body {
    padding: var(--modal-padding);
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: var(--modal-padding);
  }
  .grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: var(--modal-padding);
  }
  .info-card {
    background: var(--card-bg);
    padding: var(--modal-padding);
    border-radius: var(--card-border-radius);
    box-shadow: var(--card-shadow);
  }
  .info-card h3 {
    margin-top: 0;
    margin-bottom: 1rem;
    font-size: 1.1rem;
    border-bottom: 1px solid #e9ecef;
    padding-bottom: 0.5rem;
  }
  .info-card p { margin: 0.5rem 0; }
  
  .status-control { display: flex; align-items: center; gap: 0.5rem; }
  .status-control select {
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    border: 1px solid #ced4da;
  }
  
  .table-wrapper { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #e9ecef; }
  th { background-color: #f8f9fa; }
  td:last-child, th:last-child { text-align: right; }
  tbody tr:last-child td { border-bottom: none; }

  .financial-grid {
    display: grid;
    grid-template-columns: auto auto;
    justify-content: space-between;
    gap: 0.5rem;
  }
  .financial-grid .total {
    font-weight: bold;
    margin-top: 0.5rem;
    padding-top: 0.5rem;
    border-top: 1px solid #e9ecef;
  }

  .alert.error {
    background-color: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: var(--card-border-radius);
  }

  .confirm-modal-backdrop { z-index: 1100; }
  .confirm-modal-content {
    background: white;
    max-width: 400px;
    padding: var(--modal-padding);
    text-align: center;
  }
  .confirm-modal-content p {
    margin: 1rem 0;
  }
  .modal-actions {
    display: flex; justify-content: center; gap: 1rem; margin-top: 1.5rem;
  }
  .btn {
    padding: 0.6rem 1.2rem; border-radius: 6px; border: none;
    cursor: pointer; font-weight: 500;
  }
  .btn.danger { background-color: #dc3545; color: white; }
</style> 