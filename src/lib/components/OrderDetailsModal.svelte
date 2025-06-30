<script lang="ts">
  import { fade, scale } from 'svelte/transition';
  import type { Order, OrderStatus } from '$lib/types/orders';
  import { updateOrderStatus, reapplyOrderStock } from '$lib/services/orderService';
  import { supabase } from '$lib/supabase';
  import { getUserBalance } from '$lib/services/orderService';
  import { getStoreSettings, formatCurrency, type StoreSettings } from '$lib/services/settingsService';
  import { onMount } from 'svelte';
  import type { Transaction, TransactionCategory } from '$lib/types/ledger';

  export let order: Order;
  export let onClose: () => void;
  export let onStatusUpdate: (orderId: string, status: OrderStatus) => void;

  let loading = false;
  let error: string | null = null;
  let ledgerEntries: Transaction[] = [];
  let loadingLedger = false;
  let userBalance: number | null = null;
  let storeSettings: StoreSettings | null = null;

  // @ts-ignore
  let html2pdf: any = null;
  let showCancelConfirm = false;
  let showCompleteModal = false;
  
  // Track the current status separately to avoid binding issues
  let currentStatus: OrderStatus = order.status;
  let originalStatus: OrderStatus = order.status;
  
  // Update currentStatus when order changes
  $: if (order) {
    currentStatus = order.status;
    originalStatus = order.status;
  }
  
  // Payment collection variables for completing pending orders
  let paymentAmount = 0;
  let paymentMethod = 'cash';
  let extraCashOption: 'change' | 'credit' = 'change';

  // Calculate financials properly using settings
  $: subtotal = order.subtotal ?? (order.order_items || []).reduce((sum, item) => sum + item.price * item.quantity, 0);
  $: tax = order.tax ?? 0;
  $: shipping_fee = order.shipping_fee ?? 0;
  $: total = subtotal + tax + shipping_fee;

  // Initialize payment amount to order total when modal opens
  $: if (order && paymentAmount === 0) {
    paymentAmount = total;
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function formatCurrencyLocal(amount: number) {
    if (storeSettings) {
      return formatCurrency(amount, storeSettings.currency);
    }
    return `R${(amount ?? 0).toFixed(2)}`;
  }

  function formatCategory(category: TransactionCategory) {
    const map: Record<string, string> = {
      sale: 'Sale',
      cash_payment: 'Cash Payment',
      credit_payment: 'Paid with Credit',
      overpayment_credit: 'Overpayment to Credit',
      cash_change: 'Change Given',
      debt_payment: 'Debt Payment',
      cancellation: 'Order Cancellation',
      pos_sale: 'POS Sale',
      online_sale: 'Online Sale',
      credit_adjustment: 'Credit Adjustment',
      debit_adjustment: 'Debit Adjustment',
      balance_adjustment: 'Balance Adjustment'
    };
    return map[category] || category.replace(/_/g, ' ').replace(/\b\w/g, (l: string) => l.toUpperCase());
  }

  async function handleStatusChange(event: Event) {
    const select = event.target as HTMLSelectElement;
    const newStatus = select.value as OrderStatus;
    
    console.log('Status change triggered:', { newStatus, originalStatus, currentStatus });
    
    if (newStatus === 'cancelled') {
      showCancelConfirm = true;
      // Reset the select back to original status
      currentStatus = originalStatus;
      return;
    }
    
    if (newStatus === 'completed' && originalStatus === 'pending') {
      // For pending orders, ask user how they want to complete
      console.log('Opening complete modal for pending order');
      showCompleteModal = true;
      // Reset the select back to original status until user confirms
      currentStatus = originalStatus;
      return;
    }
    
    // For other status changes, just update directly
    console.log('Direct status update to:', newStatus);
    update(newStatus);
  }

  // Alternative function to handle completion directly
  function openCompleteModal() {
    console.log('Opening complete modal directly');
    showCompleteModal = true;
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

  async function confirmComplete() {
    showCompleteModal = false;
    loading = true;
    error = null;
    
    try {
      // Call the complete_online_order function with payment details
      const { data, error: completeError } = await supabase.rpc('complete_online_order', {
        p_order_id: order.id,
        p_payment_amount: paymentAmount,
        p_payment_method: paymentMethod,
        p_extra_cash_option: extraCashOption
      });
      
      if (completeError) {
        console.error('Error completing order:', completeError);
        error = completeError.message || 'Failed to complete order';
        loading = false;
        return;
      }
      
      if (data && data.success) {
        // Refresh the ledger entries
        await loadLedgerEntries();
        // Update the status tracking
        currentStatus = 'completed';
        originalStatus = 'completed';
        onStatusUpdate(order.id, 'completed');
      } else {
        error = data?.error || 'Failed to complete order';
      }
    } catch (err) {
      console.error('Unexpected error completing order:', err);
      error = 'An unexpected error occurred';
    } finally {
      loading = false;
    }
  }

  async function completeOnCredit() {
    showCompleteModal = false;
    loading = true;
    error = null;
    
    try {
      // Complete order without payment (amount = 0)
      const { data, error: completeError } = await supabase.rpc('complete_online_order', {
        p_order_id: order.id,
        p_payment_amount: 0,
        p_payment_method: 'credit',
        p_extra_cash_option: 'credit'
      });
      
      if (completeError) {
        console.error('Error completing order on credit:', completeError);
        error = completeError.message || 'Failed to complete order';
        loading = false;
        return;
      }
      
      if (data && data.success) {
        // Refresh the ledger entries
        await loadLedgerEntries();
        // Update the status tracking
        currentStatus = 'completed';
        originalStatus = 'completed';
        onStatusUpdate(order.id, 'completed');
      } else {
        error = data?.error || 'Failed to complete order';
      }
    } catch (err) {
      console.error('Unexpected error completing order on credit:', err);
      error = 'An unexpected error occurred';
    } finally {
      loading = false;
    }
  }

  async function update(newStatus: OrderStatus) {
    loading = true;
    error = null;
    const { success, error: updateError } = await updateOrderStatus(order.id, newStatus);
    if (success) {
      // Update the status tracking
      currentStatus = newStatus;
      originalStatus = newStatus;
      onStatusUpdate(order.id, newStatus);
    } else {
      error = updateError;
      // Reset to original status on error
      currentStatus = originalStatus;
    }
    loading = false;
  }

  function closeCompleteModal() {
    showCompleteModal = false;
    // Reset the select back to original status
    currentStatus = originalStatus;
  }

  function closeCancelModal() {
    showCancelConfirm = false;
    // Reset the select back to original status
    currentStatus = originalStatus;
  }

  function getCustomerInfo() {
    if (order.guest_info) return { ...order.guest_info, type: 'Guest' };
    if (order.user) return { name: order.user.display_name, email: order.user.email, phone: order.user.phone_number, address: order.user.address, type: 'Registered' };
    return { name: 'N/A', email: 'N/A', phone: 'N/A', address: 'N/A', type: 'Unknown' };
  }
  
  $: customer = getCustomerInfo();
  
  $: if (order && order.user && (order.user as any).auth_user_id) {
    getUserBalance((order.user as any).auth_user_id).then(b => userBalance = b);
  }

  async function loadLedgerEntries() {
    if (order.id) {
      loadingLedger = true;
      const { data } = await supabase.from('transactions').select('*').eq('order_id', order.id);
      ledgerEntries = data || [];
      loadingLedger = false;
    }
  }

  onMount(async () => {
    if (typeof window !== 'undefined') {
      html2pdf = (await import('html2pdf.js')).default;
    }
    
    // Load store settings
    storeSettings = await getStoreSettings();
    
    // Load ledger entries
    await loadLedgerEntries();
  });

  async function exportToPDF() {
    const element = document.getElementById('invoice-content');
    if (!element) return;
    
    const invoiceNumber = order.order_number || order.id;
    const opt = {
      margin: 0.5,
      filename: `invoice_${invoiceNumber}.pdf`,
      image: { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 2, useCORS: true },
      jsPDF: { unit: 'in', format: 'a4', orientation: 'portrait' }
    };
    await html2pdf().from(element).set(opt).save();
  }

  function getStatusBadgeClass(status: string) {
    switch (status) {
      case 'completed': return 'status-completed';
      case 'processing': return 'status-processing';
      case 'pending': return 'status-pending';
      case 'cancelled': return 'status-cancelled';
      default: return 'status-pending';
    }
  }
</script>

<div 
  class="modal-backdrop" 
  role="dialog" 
  aria-modal="true" 
  aria-labelledby="order-modal-title"
  tabindex="-1"
  on:click={onClose}
  on:keydown={(e) => { if (e.key === 'Escape') onClose(); }}
>
  <div 
    class="modal-content" 
    role="document"
    tabindex="0"
    on:click|stopPropagation
    on:keydown|stopPropagation
  >
    <div class="modal-header">
      <h2 id="order-modal-title" class="neon-text-cyan">Order Details</h2>
      <div class="header-actions">
        <button class="icon-btn" on:click={exportToPDF} title="Download PDF Invoice">
          📄 Download PDF
        </button>
        <button class="close-btn" on:click={onClose} aria-label="Close">&times;</button>
      </div>
    </div>
    
    <div class="modal-body">
      {#if error}
        <div class="alert error">{error}</div>
      {/if}

      <!-- Invoice Content for PDF Export -->
      <div id="invoice-content" class="invoice-container">
        <!-- Invoice Header -->
        <div class="invoice-header">
          <div class="company-info">
            {#if storeSettings}
              <h1 class="company-name">{storeSettings.store_name}</h1>
              <div class="company-details">
                <p>{storeSettings.store_address}</p>
                <p>📞 {storeSettings.store_phone}</p>
                <p>✉️ {storeSettings.store_email}</p>
              </div>
            {:else}
              <h1 class="company-name">Loading...</h1>
            {/if}
          </div>
          <div class="invoice-meta">
            <h2 class="invoice-title">INVOICE</h2>
            <div class="invoice-details">
              <p><strong>Invoice #:</strong> {order.order_number || order.id}</p>
              <p><strong>Date:</strong> {formatDate(order.created_at)}</p>
              <p><strong>Status:</strong> <span class="status-badge {getStatusBadgeClass(order.status)}">{order.status.toUpperCase()}</span></p>
              {#if order.note && order.note.includes('POS User:')}
                <p><strong>Cashier:</strong> {order.note.split('POS User:')[1]?.trim() || 'Unknown'}</p>
              {:else if order.is_pos_order}
                <p><strong>Cashier:</strong> POS Terminal</p>
              {/if}
            </div>
          </div>
        </div>

        <!-- Bill To Section -->
        <div class="billing-section">
          <div class="bill-to">
            <h3>Bill To:</h3>
            <div class="customer-details">
              <p><strong>{customer.name}</strong></p>
          <p>{customer.email}</p>
              {#if customer.phone && customer.phone !== 'N/A'}
          <p>{customer.phone}</p>
              {/if}
              {#if customer.address && customer.address !== 'N/A'}
          <p>{customer.address}</p>
              {/if}
              <p class="customer-type">({customer.type} Customer)</p>
            </div>
          </div>
          
          <div class="payment-info">
            <h3>Payment Details:</h3>
            <p><strong>Method:</strong> {order.payment_method || 'Cash'}</p>
            {#if order.is_pos_order}
              <p><strong>Type:</strong> Point of Sale</p>
            {:else}
              <p><strong>Type:</strong> Online Order</p>
            {/if}
          </div>
        </div>

        <!-- Items Table -->
        <div class="items-section">
          <table class="items-table">
            <thead>
              <tr>
                <th class="item-desc">Description</th>
                <th class="item-qty">Qty</th>
                <th class="item-price">Unit Price</th>
                <th class="item-total">Total</th>
              </tr>
            </thead>
            <tbody>
              {#each order.order_items || [] as item}
                <tr>
                  <td class="item-desc">{item.products?.name || 'Product not found'}</td>
                  <td class="item-qty">{item.quantity}</td>
                  <td class="item-price">{formatCurrencyLocal(item.price)}</td>
                  <td class="item-total">{formatCurrencyLocal(item.price * item.quantity)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <!-- Totals Section -->
        <div class="totals-section">
          <div class="totals-table">
            <div class="total-row">
              <span>Subtotal:</span>
              <span>{formatCurrencyLocal(subtotal)}</span>
            </div>
            {#if !order.is_pos_order && shipping_fee > 0}
              <div class="total-row">
                <span>Shipping:</span>
                <span>{formatCurrencyLocal(shipping_fee)}</span>
              </div>
            {/if}
            {#if tax > 0}
              <div class="total-row">
                <span>Tax ({storeSettings?.tax_rate || 15}%):</span>
                <span>{formatCurrencyLocal(tax)}</span>
              </div>
            {/if}
            <div class="total-row final-total">
              <span><strong>Total:</strong></span>
              <span><strong>{formatCurrencyLocal(total)}</strong></span>
            </div>
          </div>
        </div>

        <!-- Admin Controls (not printed) -->
        <div class="admin-controls no-print">
          <div class="status-control">
            <label for="status-select" class="form-label">
              Status:
              {#if originalStatus === 'pending'}
                <span class="status-helper">Selecting "Completed" will open payment collection options</span>
              {/if}
            </label>
            <select 
              id="status-select"
              bind:value={currentStatus} 
              on:change={handleStatusChange}
              class="form-control form-select"
            >
              <option value="pending">Pending</option>
              <option value="processing">Processing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          
          {#if originalStatus === 'pending'}
            <div class="completion-actions">
              <button 
                class="btn btn-primary btn-sm"
                on:click={openCompleteModal}
                disabled={loading}
              >
                🎯 Complete Order
              </button>
              <p class="helper-text">Click here if the dropdown isn't working</p>
            </div>
          {/if}
        </div>

        <!-- Transaction Ledger (not printed) -->
        {#if ledgerEntries.length > 0}
          <div class="ledger-section no-print">
            <h3>Transaction History</h3>
            <div class="ledger-table">
              <div class="ledger-header">
                <div>Description</div>
                <div>Cash Amount</div>
                <div>Balance Impact</div>
              </div>
              {#each ledgerEntries as entry (entry.id)}
                <div class="ledger-row">
                  <div>{formatCategory(entry.category)}</div>
                  <div class:positive={entry.cash_amount > 0} class:negative={entry.cash_amount < 0}>
                    {formatCurrencyLocal(entry.cash_amount)}
                  </div>
                  <div class:positive={entry.balance_amount > 0} class:negative={entry.balance_amount < 0}>
                    {formatCurrencyLocal(entry.balance_amount)}
                  </div>
                </div>
              {/each}
            </div>
            {#if customer.type !== 'Guest' && userBalance !== null}
              <p class="user-balance"><strong>Current Customer Balance:</strong> {formatCurrencyLocal(userBalance)}</p>
            {/if}
          </div>
        {/if}

        <!-- Invoice Footer -->
        <div class="invoice-footer">
          <p class="thank-you">Thank you for your business!</p>
          {#if storeSettings?.business_hours}
            <div class="business-hours">
              <p><strong>Business Hours:</strong></p>
              <p>Monday - Friday: 9:00 AM - 5:00 PM</p>
              <p>Saturday: 9:00 AM - 1:00 PM</p>
            </div>
          {/if}
        </div>
      </div>
    </div>
  </div>
</div>

<!-- Payment Collection Modal for Completing Pending Orders -->
{#if showCompleteModal}
  <div class="modal-overlay" on:click={closeCompleteModal} transition:fade>
    <div class="payment-modal glass" on:click|stopPropagation transition:scale>
      <div class="modal-header">
        <h3 class="neon-text-cyan">Complete Order</h3>
        <button class="close-btn" on:click={closeCompleteModal}>×</button>
      </div>
      
      <div class="modal-body">
        <div class="order-summary-section">
          <h4>Order Summary</h4>
          <div class="summary-row">
            <span>Order Total:</span>
            <span class="neon-text-cyan">{formatCurrencyLocal(total)}</span>
          </div>
          <div class="summary-row">
            <span>Customer:</span>
            <span>{customer.name}</span>
          </div>
          {#if userBalance !== null}
            <div class="summary-row">
              <span>Current Balance:</span>
              <span class={userBalance < 0 ? 'text-red' : userBalance > 0 ? 'text-green' : ''}>
                {userBalance < 0 ? `Debt: ${formatCurrencyLocal(Math.abs(userBalance))}` : 
                 userBalance > 0 ? `Credit: ${formatCurrencyLocal(userBalance)}` : 
                 'R0.00'}
              </span>
            </div>
          {/if}
        </div>

        <div class="completion-options">
          <div class="option-card">
            <h4 class="neon-text-cyan">Option 1: Collect Payment</h4>
            <p class="option-description">Customer pays cash/card and takes the products</p>
            
            <div class="payment-section">
              <div class="form-group">
                <label class="form-label">Payment Method:</label>
                <select bind:value={paymentMethod} class="form-control form-select">
                  <option value="cash">Cash</option>
                  <option value="card">Card</option>
                  <option value="eft">EFT</option>
                </select>
              </div>

              <div class="form-group">
                <label class="form-label">Payment Amount: <span class="helper-text">(set to 0 for partial payment)</span></label>
                <input 
                  type="number" 
                  bind:value={paymentAmount} 
                  min="0" 
                  step="0.01" 
                  class="form-control"
                  placeholder="Enter payment amount"
                />
              </div>

              {#if paymentAmount > total}
                <div class="form-group">
                  <label class="form-label">Handle Overpayment:</label>
                  <div class="radio-group">
                    <label class="radio-option">
                      <input type="radio" bind:group={extraCashOption} value="change" />
                      <span>Give Change ({formatCurrencyLocal(paymentAmount - total)})</span>
                    </label>
                    <label class="radio-option">
                      <input type="radio" bind:group={extraCashOption} value="credit" />
                      <span>Credit to Account ({formatCurrencyLocal(paymentAmount - total)})</span>
                    </label>
                  </div>
                </div>
              {/if}

              <div class="payment-summary">
                <div class="summary-row">
                  <span>Payment Received:</span>
                  <span class="neon-text-cyan">{formatCurrencyLocal(paymentAmount)}</span>
                </div>
                {#if paymentAmount >= total}
                  <div class="summary-row">
                    <span>Change/Credit:</span>
                    <span class="neon-text-green">{formatCurrencyLocal(Math.max(0, paymentAmount - total))}</span>
                  </div>
                {:else}
                  <div class="summary-row">
                    <span>Remaining Debt:</span>
                    <span class="text-red">{formatCurrencyLocal(total - paymentAmount)}</span>
                  </div>
                {/if}
              </div>
            </div>
          </div>

          <div class="option-divider">
            <span>OR</span>
          </div>

          <div class="option-card">
            <h4 class="neon-text-orange">Option 2: Complete on Credit</h4>
            <p class="option-description">Customer takes products now, pays later (adds to their debt)</p>
            <div class="credit-info">
              <div class="summary-row">
                <span>Amount to be added to debt:</span>
                <span class="text-red">{formatCurrencyLocal(total)}</span>
              </div>
              {#if userBalance !== null}
                <div class="summary-row">
                  <span>New balance after credit:</span>
                  <span class="text-red">Debt: {formatCurrencyLocal(Math.abs(userBalance) + total)}</span>
                </div>
              {/if}
            </div>
          </div>
        </div>
      </div>

      <div class="modal-actions">
        <button class="btn btn-secondary" on:click={closeCompleteModal}>
          Cancel
        </button>
        <button 
          class="btn btn-primary" 
          on:click={confirmComplete}
          disabled={loading}
        >
          {loading ? 'Processing...' : 'Complete with Payment'}
        </button>
        <button 
          class="btn btn-warning" 
          on:click={completeOnCredit}
          disabled={loading}
        >
          {loading ? 'Processing...' : 'Complete on Credit'}
        </button>
      </div>
    </div>
  </div>
{/if}

{#if showCancelConfirm}
  <div class="modal-overlay" on:click={closeCancelModal} transition:fade>
    <div class="confirm-modal glass" on:click|stopPropagation transition:scale>
      <div class="modal-header">
        <h3 class="neon-text-cyan">Confirm Cancellation</h3>
        <button class="close-btn" on:click={closeCancelModal}>×</button>
      </div>
      
      <div class="modal-body">
        <p>Are you sure you want to cancel this order? This will:</p>
        <ul>
          <li>Mark the order as cancelled</li>
          <li>Restore stock levels for all items</li>
          <li>Add a cancellation transaction to reverse the sale</li>
        </ul>
        <p><strong>This action cannot be undone.</strong></p>
      </div>

      <div class="modal-actions">
        <button class="btn btn-secondary" on:click={closeCancelModal}>
          No, Keep Order
        </button>
        <button 
          class="btn btn-danger" 
          on:click={confirmCancel}
          disabled={loading}
        >
          {loading ? 'Cancelling...' : 'Yes, Cancel Order'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* Print styles */
  @media print {
    .no-print {
      display: none !important;
    }
    .modal-backdrop, .modal-header {
      display: none !important;
    }
    .invoice-container {
      margin: 0 !important;
      box-shadow: none !important;
      border: none !important;
  }
  }

  /* Order modal specific overrides */
  .modal-content {
    background: #f8f9fa;
    max-width: 900px;
    width: 95vw;
    max-height: 95vh;
    overflow: hidden;
  }
  
  .modal-header {
    display: flex; justify-content: space-between; align-items: center;
    padding: 1.5rem 2rem;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-bottom: none;
  }
  
  .modal-header h2 { 
    margin: 0; 
    font-size: 1.5rem; 
    font-weight: 600;
  }
  
  .header-actions {
    display: flex;
    gap: 1rem;
    align-items: center;
  }
  
  .icon-btn {
    background: rgba(255,255,255,0.2);
    border: 1px solid rgba(255,255,255,0.3);
    color: white;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.9rem;
    transition: all 0.2s;
  }
  
  .icon-btn:hover {
    background: rgba(255,255,255,0.3);
  }
  
  .close-btn {
    background: none; 
    border: none; 
    font-size: 2rem; 
    cursor: pointer;
    color: white; 
    line-height: 1; 
    padding: 0;
    transition: opacity 0.2s;
  }
  
  .close-btn:hover { 
    opacity: 0.7; 
  }
  
  .modal-body {
    overflow-y: auto;
    flex: 1;
  }

  /* Invoice Styles */
  .invoice-container {
    background: white;
    margin: 0;
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
  }

  .invoice-header {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
    padding: 2rem;
    border-bottom: 3px solid #667eea;
    margin-bottom: 2rem;
  }

  .company-name {
    font-size: 2rem;
    font-weight: bold;
    color: #667eea;
    margin: 0 0 0.5rem 0;
  }

  .company-details p {
    margin: 0.25rem 0;
    color: #666;
  }

  .invoice-title {
    font-size: 2.5rem;
    font-weight: bold;
    color: #333;
    margin: 0;
    text-align: right;
  }

  .invoice-details {
    text-align: right;
    margin-top: 1rem;
  }

  .invoice-details p {
    margin: 0.5rem 0;
  }

  .status-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: bold;
    text-transform: uppercase;
  }

  .status-completed { background: #d4edda; color: #155724; }
  .status-processing { background: #fff3cd; color: #856404; }
  .status-pending { background: #cce5ff; color: #004085; }
  .status-cancelled { background: #f8d7da; color: #721c24; }

  .billing-section {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
    padding: 0 2rem;
    margin-bottom: 2rem;
  }

  .bill-to h3, .payment-info h3 {
    color: #667eea;
    margin-bottom: 1rem;
    font-size: 1.1rem;
    text-transform: uppercase;
    font-weight: 600;
  }

  .customer-details p, .payment-info p {
    margin: 0.5rem 0;
  }

  .customer-type {
    color: #666;
    font-style: italic;
  }

  .items-section {
    padding: 0 2rem;
    margin-bottom: 2rem;
  }

  .items-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 2rem;
  }

  .items-table th {
    background: #f8f9fa;
    padding: 1rem;
    text-align: left;
    font-weight: 600;
    color: #333;
    border-bottom: 2px solid #667eea;
  }

  .items-table td {
    padding: 1rem;
    border-bottom: 1px solid #e9ecef;
  }

  .item-qty, .item-price, .item-total {
    text-align: right;
    width: 100px;
  }

  .totals-section {
    padding: 0 2rem;
    margin-bottom: 2rem;
  }

  .totals-table {
    max-width: 400px;
    margin-left: auto;
    background: #f8f9fa;
    padding: 1.5rem;
    border-radius: 8px;
  }

  .total-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0;
    border-bottom: 1px solid #e9ecef;
  }

  .final-total {
    border-top: 2px solid #667eea;
    border-bottom: none;
    font-size: 1.2rem;
    margin-top: 0.5rem;
    padding-top: 1rem;
  }

  .admin-controls {
    padding: 1rem 2rem;
    background: #f8f9fa;
    border-top: 1px solid #e9ecef;
  }
  
  .status-control {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .status-control select {
    padding: 0.5rem;
    border-radius: 4px;
    border: 1px solid #ced4da;
  }

  .completion-actions {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #e9ecef;
  }

  .completion-actions button {
    margin-bottom: 0.5rem;
  }
  
  .ledger-section {
    padding: 1rem 2rem;
    background: #f8f9fa;
    border-top: 1px solid #e9ecef;
  }

  .ledger-section h3 {
    color: #667eea;
    margin-bottom: 1rem;
  }

  .ledger-table {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    font-size: 0.9rem;
  }

  .ledger-header, .ledger-row {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr;
    gap: 1rem;
    padding: 0.75rem;
    text-align: right;
  }

  .ledger-header {
    font-weight: bold;
    color: #666;
    background: white;
    border-radius: 4px;
  }

  .ledger-row {
    background: white;
    border-radius: 4px;
  }

  .ledger-row > div:first-child {
    text-align: left;
    font-weight: 500;
  }

  .positive { color: #28a745; }
  .negative { color: #dc3545; }

  .user-balance {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #e9ecef;
    text-align: right;
    font-size: 1rem;
  }

  .invoice-footer {
    padding: 2rem;
    text-align: center;
    border-top: 1px solid #e9ecef;
    background: #f8f9fa;
  }

  .thank-you {
    font-size: 1.2rem;
    color: #667eea;
    font-weight: 600;
    margin-bottom: 1rem;
  }

  .business-hours p {
    margin: 0.25rem 0;
    color: #666;
  }

  .alert.error {
    background-color: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 6px;
    margin: 1rem 2rem;
  }

  .confirm-modal-backdrop { z-index: 1100; }
  .confirm-modal-content {
    background: white;
    max-width: 400px;
    padding: 2rem;
    text-align: center;
    border-radius: 12px;
  }
  .confirm-modal-content p {
    margin: 1rem 0;
  }
  .modal-actions {
    display: flex; justify-content: center; gap: 1rem; margin-top: 1.5rem;
  }
  .btn.danger { background-color: #dc3545; color: white; }

  @media (max-width: 768px) {
    .invoice-header,
    .billing-section {
      grid-template-columns: 1fr;
      gap: 1rem;
    }
    
    .invoice-title {
      text-align: left;
      font-size: 2rem;
    }
    
    .invoice-details {
      text-align: left;
    }
  }

  .payment-modal {
    max-width: 500px;
    width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    padding: 0;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 1px solid var(--border-primary);
  }

  .modal-header h3 {
    margin: 0;
    font-size: 1.2rem;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    color: var(--text-muted);
    cursor: pointer;
    padding: 0;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    color: var(--neon-cyan);
  }

  .modal-body {
    padding: 1.5rem;
  }

  .order-summary-section {
    margin-bottom: 1.5rem;
    padding: 1rem;
    background: var(--bg-glass-light);
    border-radius: 8px;
    border: 1px solid var(--border-primary);
  }

  .order-summary-section h4 {
    margin: 0 0 1rem 0;
    color: var(--text-primary);
    font-size: 1rem;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--border-primary);
  }

  .summary-row:last-child {
    border-bottom: none;
  }

  .payment-section {
    margin-bottom: 1rem;
  }

  .form-group {
    margin-bottom: 1rem;
  }

  .radio-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .radio-option {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    border-radius: 4px;
    background: var(--bg-glass-light);
    border: 1px solid var(--border-primary);
    cursor: pointer;
  }

  .radio-option:hover {
    border-color: var(--neon-cyan);
  }

  .radio-option input[type="radio"] {
    margin: 0;
  }

  .payment-summary {
    margin-top: 1rem;
    padding: 1rem;
    background: var(--bg-glass-light);
    border-radius: 8px;
    border: 1px solid var(--border-primary);
  }

  .modal-actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    padding: 1.5rem;
    border-top: 1px solid var(--border-primary);
  }

  .text-red {
    color: #dc3545;
  }

  .text-green {
    color: #28a745;
  }

  .neon-text-green {
    color: #43e97b;
    text-shadow: 0 0 8px rgba(67, 233, 123, 0.4);
  }

  @media (max-width: 768px) {
    .payment-modal {
      width: 95%;
      max-height: 95vh;
    }

    .confirm-modal {
      width: 95%;
      max-height: 95vh;
    }

    .modal-header,
    .modal-body,
    .modal-actions {
      padding: 1rem;
    }

    .radio-group {
      gap: 0.75rem;
    }

    .modal-actions {
      flex-direction: column;
    }

    .completion-options {
      gap: 1rem;
    }

    .option-card {
      padding: 0.75rem;
    }

    .option-card h4 {
      font-size: 0.9rem;
    }

    .option-description {
      font-size: 0.85rem;
    }

    .btn-warning,
    .btn-primary,
    .btn-secondary,
    .btn-danger {
      padding: 0.75rem;
      font-size: 0.9rem;
    }
  }

  .completion-options {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .option-card {
    padding: 1rem;
    background: var(--bg-glass-light);
    border-radius: 8px;
    border: 1px solid var(--border-primary);
  }

  .option-card h4 {
    margin: 0 0 0.5rem 0;
    font-size: 1rem;
  }

  .option-description {
    margin: 0 0 1rem 0;
    color: var(--text-muted);
    font-size: 0.9rem;
  }

  .option-divider {
    text-align: center;
    position: relative;
    margin: 0.5rem 0;
  }

  .option-divider::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 1px;
    background: var(--border-primary);
  }

  .option-divider span {
    background: var(--bg-card);
    padding: 0 1rem;
    color: var(--text-muted);
    font-weight: 500;
  }

  .credit-info {
    background: rgba(220, 53, 69, 0.1);
    border: 1px solid rgba(220, 53, 69, 0.3);
    border-radius: 6px;
    padding: 0.75rem;
  }

  .helper-text {
    font-size: 0.8rem;
    color: var(--text-muted);
    font-weight: normal;
  }

  .neon-text-orange {
    color: #ff6a00;
    text-shadow: 0 0 8px rgba(255, 106, 0, 0.4);
  }

  .btn-warning {
    background: linear-gradient(135deg, #ff6a00, #ee0979);
    color: white;
    border: 1px solid #ff6a00;
  }

  .btn-warning:hover {
    background: linear-gradient(135deg, #e55a00, #d10869);
    box-shadow: 0 0 15px rgba(255, 106, 0, 0.4);
  }

  .btn-warning:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .status-helper {
    display: block;
    font-size: 0.8rem;
    color: var(--text-muted);
    font-weight: normal;
    margin-top: 0.25rem;
  }

  .confirm-modal {
    max-width: 400px;
    width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    padding: 0;
  }

  .confirm-modal .modal-body ul {
    margin: 1rem 0;
    padding-left: 1.5rem;
    color: var(--text-muted);
  }

  .confirm-modal .modal-body li {
    margin-bottom: 0.5rem;
  }

  .btn-danger {
    background: linear-gradient(135deg, #dc3545, #c82333);
    color: white;
    border: 1px solid #dc3545;
  }

  .btn-danger:hover {
    background: linear-gradient(135deg, #c82333, #a71e2a);
    box-shadow: 0 0 15px rgba(220, 53, 69, 0.4);
  }

  .btn-danger:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
</style> 