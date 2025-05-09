<script lang="ts">
  import { fade, scale } from 'svelte/transition';
  import type { Order, OrderStatus } from '$lib/types/orders';
  import { updateOrderStatus } from '$lib/services/orderService';

  export let order: Order;
  export let onClose: () => void;
  export let onStatusUpdate: (orderId: string, status: OrderStatus) => void;

  let loading = false;
  let error: string | null = null;

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleString();
  }

  function formatCurrency(amount: number) {
    return `R${amount.toFixed(2)}`;
  }

  async function handleStatusChange(event: Event) {
    const select = event.target as HTMLSelectElement;
    const newStatus = select.value as OrderStatus;
    
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
    if (order.guest_info) {
      return {
        name: order.guest_info.name,
        email: order.guest_info.email,
        phone: order.guest_info.phone,
        address: order.guest_info.address,
        type: 'Guest'
      };
    } else if (order.user) {
      return {
        name: order.user.user_metadata?.name || 'N/A',
        email: order.user.email,
        phone: order.user.user_metadata?.phone || 'N/A',
        address: order.user.user_metadata?.address || 'N/A',
        type: 'Registered User'
      };
    }
    return {
      name: 'N/A',
      email: 'N/A',
      phone: 'N/A',
      address: 'N/A',
      type: 'Unknown'
    };
  }

  $: customer = getCustomerInfo();
</script>

<div class="modal-backdrop" on:click={onClose} transition:fade>
  <div 
    class="modal-content" 
    on:click|stopPropagation 
    transition:scale={{duration: 300, start: 0.95}}
  >
    <div class="modal-header">
      <h2>Order Details</h2>
      <button class="close-btn" on:click={onClose}>&times;</button>
    </div>

    {#if error}
      <div class="error-message" transition:fade>{error}</div>
    {/if}

    <div class="order-info">
      <div class="info-section">
        <h3>Order Information</h3>
        <div class="info-grid">
          <div class="info-item">
            <span class="label">Order ID:</span>
            <span class="value">{order.order_number || order.id}</span>
          </div>
          <div class="info-item">
            <span class="label">Date:</span>
            <span class="value">{formatDate(order.created_at)}</span>
          </div>
          <div class="info-item">
            <span class="label">Status:</span>
            <select 
              value={order.status} 
              on:change={handleStatusChange}
              disabled={loading}
            >
              <option value="pending">Pending</option>
              <option value="processing">Processing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          <div class="info-item">
            <span class="label">Total:</span>
            <span class="value">{formatCurrency(order.total)}</span>
          </div>
        </div>
      </div>

      <div class="info-section">
        <h3>Customer Information ({customer.type})</h3>
        <div class="info-grid">
          <div class="info-item">
            <span class="label">Name:</span>
            <span class="value">{customer.name}</span>
          </div>
          <div class="info-item">
            <span class="label">Email:</span>
            <span class="value">{customer.email}</span>
          </div>
          <div class="info-item">
            <span class="label">Phone:</span>
            <span class="value">{customer.phone}</span>
          </div>
          <div class="info-item">
            <span class="label">Address:</span>
            <span class="value">{customer.address}</span>
          </div>
        </div>
      </div>

      <div class="info-section">
        <h3>Order Items</h3>
        <div class="items-table">
          <table>
            <thead>
              <tr>
                <th>Product</th>
                <th>Price</th>
                <th>Quantity</th>
                <th>Subtotal</th>
              </tr>
            </thead>
            <tbody>
              {#each order.order_items || [] as item}
                <tr>
                  <td>
                    <div class="product-info">
                      {#if item.product?.image_url}
                        <img 
                          src={item.product.image_url} 
                          alt={item.product.name}
                          width="40"
                          height="40"
                        />
                      {/if}
                      <span>{item.product?.name || 'Unknown Product'}</span>
                    </div>
                  </td>
                  <td>{formatCurrency(item.price)}</td>
                  <td>{item.quantity}</td>
                  <td>{formatCurrency(item.price * item.quantity)}</td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr>
                <td colspan="3" class="total-label">Total</td>
                <td class="total-value">{formatCurrency(order.total)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: 2rem;
    z-index: 1000;
    overflow-y: auto;
  }

  .modal-content {
    background: white;
    border-radius: 12px;
    width: 100%;
    max-width: 800px;
    padding: 1.5rem;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  .modal-header h2 {
    margin: 0;
    color: #333;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.5rem;
    color: #666;
    transition: color 0.2s;
  }

  .close-btn:hover {
    color: #333;
  }

  .info-section {
    margin-bottom: 2rem;
  }

  .info-section h3 {
    color: #333;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #eee;
  }

  .info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
  }

  .info-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .label {
    font-size: 0.9rem;
    color: #666;
  }

  .value {
    font-weight: 500;
    color: #333;
  }

  select {
    padding: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    background: white;
    cursor: pointer;
  }

  select:disabled {
    background: #f5f5f5;
    cursor: not-allowed;
  }

  .items-table {
    overflow-x: auto;
  }

  table {
    width: 100%;
    border-collapse: collapse;
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

  .product-info {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .product-info img {
    border-radius: 4px;
    object-fit: cover;
  }

  tfoot tr {
    font-weight: 600;
  }

  .total-label {
    text-align: right;
  }

  .total-value {
    color: #28a745;
  }

  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
  }

  @media (max-width: 768px) {
    .modal-backdrop {
      padding: 1rem;
    }

    .info-grid {
      grid-template-columns: 1fr;
    }

    th, td {
      padding: 0.75rem;
    }
  }
</style> 