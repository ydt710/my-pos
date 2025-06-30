<script lang="ts">
  import { fade } from 'svelte/transition';
  import type { Order } from '$lib/types/orders';
  import { getStoreSettings, formatCurrency, type StoreSettings } from '$lib/services/settingsService';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';

  export let order: Order;
  export let onClose: () => void;

  let storeSettings: StoreSettings | null = null;
  let orderTransactions: any[] = [];
  let currentUser: any = null;

  // Calculate financials
  $: subtotal = order.subtotal ?? (order.order_items || []).reduce((sum, item) => sum + item.price * item.quantity, 0);
  $: tax = order.tax ?? 0;
  $: shipping_fee = order.shipping_fee ?? 0;
  $: total = subtotal + tax + shipping_fee;

  // Calculate payment breakdown from transactions - CORRECTED
  // Total cash given by customer (from order.cash_given or transactions)
  $: totalCashGiven = order.cash_given || orderTransactions.filter(t => ['cash_payment', 'debt_payment'].includes(t.category)).reduce((sum, t) => sum + parseFloat(t.cash_amount || 0), 0);
  
  // Debt payment (existing debt that was paid off)
  $: debtPaidOff = orderTransactions.filter(t => t.category === 'debt_payment').reduce((sum, t) => sum + parseFloat(t.balance_amount || 0), 0);
  
  // Cash payment for this order specifically  
  $: cashPaidForOrder = orderTransactions.filter(t => t.category === 'cash_payment').reduce((sum, t) => sum + parseFloat(t.balance_amount || 0), 0);
  
  // Change given back to customer (from order or transactions)
  $: changeGiven = order.change_given ?? orderTransactions.filter(t => t.category === 'cash_change').reduce((sum, t) => sum + Math.abs(parseFloat(t.cash_amount || 0)), 0);
  
  // Credit added to account from overpayment
  $: creditToAccount = orderTransactions.filter(t => t.category === 'overpayment_credit').reduce((sum, t) => sum + parseFloat(t.balance_amount || 0), 0);
  
  // New debt created from this order (sale amount)
  $: orderAmount = orderTransactions.filter(t => ['pos_sale', 'online_sale'].includes(t.category)).reduce((sum, t) => sum + Math.abs(parseFloat(t.balance_amount || 0)), 0);
  
  // Calculate if order was fully paid or created debt
  $: totalPaymentsForOrder = cashPaidForOrder + debtPaidOff + creditToAccount;
  $: unpaidDebt = Math.max(0, orderAmount - totalPaymentsForOrder);
  
  // Calculate net cash flow for verification
  $: netCashFlow = totalCashGiven - changeGiven;

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
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

  function getCustomerInfo() {
    if (order.guest_info) return { ...order.guest_info, type: 'Guest' };
    if (order.user) return { name: order.user.display_name, email: order.user.email, phone: order.user.phone_number, type: 'Customer' };
    return { name: 'Walk-in Customer', email: '', phone: '', type: 'Cash Sale' };
  }

  $: customer = getCustomerInfo();

  onMount(async () => {
    storeSettings = await getStoreSettings();
    
    // Get current user (POS user)
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name, role')
        .eq('auth_user_id', user.id)
        .single();
      currentUser = profile;
    }
    
    // Load transaction details for this order with all relevant fields
    if (order?.id) {
      const { data: transactions } = await supabase
        .from('transactions')
        .select('id, category, balance_amount, cash_amount, total_amount, note, affects_balance, affects_cash_collected, created_at')
        .eq('order_id', order.id)
        .order('created_at');
      orderTransactions = transactions || [];
      console.log('Order transactions loaded:', orderTransactions);
    }
  });

  async function printReceipt() {
    const receiptContent = document.getElementById('thermal-receipt');
    if (!receiptContent) return;

    // Create a new window for printing
    const printWindow = window.open('', '_blank', 'width=300,height=600');
    if (!printWindow) return;

    // Add thermal printer specific CSS
    const receiptHTML = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Receipt</title>
        <style>
          @media print {
            @page {
              size: 80mm auto;
              margin: 0;
            }
            body {
              margin: 0;
              padding: 0;
            }
          }
                     body {
             font-family: 'Courier New', monospace;
             font-size: 19px;
             line-height: 1.4;
             width: 80mm;
             margin: 0;
             padding: 5mm;
             background: white;
             color: black;
           }
          .receipt-header {
            text-align: center;
            border-bottom: 1px dashed #000;
            padding-bottom: 8px;
            margin-bottom: 8px;
          }
                     .store-name {
             font-weight: bold;
             font-size: 23px;
             margin-bottom: 4px;
           }
           .store-info {
             font-size: 17px;
             line-height: 1.2;
           }
           .receipt-info {
             margin: 8px 0;
             font-size: 19px;
           }
          .items-section {
            border-bottom: 1px dashed #000;
            padding-bottom: 8px;
            margin-bottom: 8px;
          }
          .item-row {
            display: flex;
            justify-content: space-between;
            margin: 2px 0;
            font-size: 19px;
          }
          .item-name {
            flex: 1;
            padding-right: 8px;
          }
          .item-qty-price {
            white-space: nowrap;
          }
          .totals-section {
            border-bottom: 1px dashed #000;
            padding-bottom: 8px;
            margin-bottom: 8px;
          }
          .total-row {
            display: flex;
            justify-content: space-between;
            margin: 2px 0;
            font-size: 19px;
          }
          .final-total {
            font-weight: bold;
            font-size: 21px;
            border-top: 1px solid #000;
            padding-top: 4px;
            margin-top: 4px;
          }
          .receipt-footer {
            text-align: center;
            font-size: 17px;
            margin-top: 8px;
          }
          .payment-info {
            margin: 8px 0;
            font-size: 19px;
          }
          .center {
            text-align: center;
          }
          .bold {
            font-weight: bold;
          }
          .dashed-line {
            border-top: 1px dashed #000;
            margin: 8px 0;
          }
        </style>
      </head>
      <body>
        ${receiptContent.innerHTML}
      </body>
      </html>
    `;

    printWindow.document.write(receiptHTML);
    printWindow.document.close();
    
    // Wait for content to load then print
    printWindow.onload = () => {
      printWindow.print();
      printWindow.close();
    };
  }
</script>

<div class="modal-backdrop" on:click={onClose} transition:fade>
  <div class="modal-content" on:click|stopPropagation>
    <div class="modal-header">
      <h3>Print Receipt</h3>
      <div class="header-actions">
        <button class="print-btn-header" on:click={printReceipt}>
          🖨️ Print
        </button>
        <button class="close-btn" on:click={onClose}>&times;</button>
      </div>
    </div>
    
    <div class="modal-body">
      <div class="receipt-preview">
        <div id="thermal-receipt" class="thermal-receipt">
          <!-- Store Header -->
          <div class="receipt-header">
            {#if storeSettings}
              <div class="store-name">{storeSettings.store_name}</div>
              <div class="store-info">
                {storeSettings.store_address}<br>
                Tel: {storeSettings.store_phone}<br>
                Email: {storeSettings.store_email}
              </div>
            {:else}
              <div class="store-name">Loading...</div>
            {/if}
          </div>

          <!-- Receipt Info -->
          <div class="receipt-info">
            <div class="center bold">SALES RECEIPT</div>
            <div>Receipt #: {order.order_number || order.id}</div>
            <div>Date: {formatDate(order.created_at)}</div>
            <div>Cashier: {currentUser?.display_name || 'POS Terminal'}</div>
            {#if customer.name !== 'Walk-in Customer'}
              <div>Customer: {customer.name}</div>
            {/if}
          </div>

          <!-- Items -->
          <div class="items-section">
            {#each order.order_items || [] as item}
              <div class="item-row">
                <div class="item-name">{item.products?.name || 'Product'}</div>
                <div class="item-qty-price">{item.quantity}x{formatCurrencyLocal(item.price)}</div>
              </div>
              <div class="item-row">
                <div class="item-name"></div>
                <div class="item-qty-price">{formatCurrencyLocal(item.price * item.quantity)}</div>
              </div>
            {/each}
          </div>

          <!-- Totals -->
          <div class="totals-section">
            <div class="total-row">
              <span>Subtotal:</span>
              <span>{formatCurrencyLocal(subtotal)}</span>
            </div>
            {#if tax > 0}
              <div class="total-row">
                <span>VAT ({storeSettings?.tax_rate || 15}%):</span>
                <span>{formatCurrencyLocal(tax)}</span>
              </div>
            {/if}
            {#if shipping_fee > 0}
              <div class="total-row">
                <span>Shipping:</span>
                <span>{formatCurrencyLocal(shipping_fee)}</span>
              </div>
            {/if}
            <div class="total-row final-total">
              <span>TOTAL:</span>
              <span>{formatCurrencyLocal(total)}</span>
            </div>
          </div>

          <!-- Payment Breakdown -->
          <div class="payment-info">
            <div class="dashed-line"></div>
            <div class="center bold">PAYMENT BREAKDOWN</div>
            
            <!-- Order Amount -->
            <div class="total-row">
              <span>Order Amount:</span>
              <span>{formatCurrencyLocal(orderAmount)}</span>
            </div>
            
            <!-- Show starting debt if any was paid off -->
            {#if debtPaidOff > 0}
              <div class="total-row">
                <span>Previous Debt Paid:</span>
                <span>{formatCurrencyLocal(debtPaidOff)}</span>
              </div>
            {/if}
            
            <!-- Total cash given by customer -->
            {#if totalCashGiven > 0}
              <div class="total-row">
                <span>Cash Given:</span>
                <span>{formatCurrencyLocal(totalCashGiven)}</span>
              </div>
            {/if}
            
            <!-- Change given back -->
            {#if changeGiven > 0}
              <div class="total-row">
                <span>Change Given:</span>
                <span>{formatCurrencyLocal(changeGiven)}</span>
              </div>
            {/if}
            
            <!-- Credit added to account -->
            {#if creditToAccount > 0}
              <div class="total-row">
                <span>Credit to Account:</span>
                <span>{formatCurrencyLocal(creditToAccount)}</span>
              </div>
            {/if}
            
            <!-- Debt created (remaining unpaid) -->
            {#if unpaidDebt > 0}
              <div class="total-row">
                <span>Debt Created:</span>
                <span>{formatCurrencyLocal(unpaidDebt)}</span>
              </div>
            {/if}
            
            <div class="dashed-line"></div>
            <div class="total-row">
              <span>Payment Method:</span>
              <span>{order.payment_method || 'Cash'} - {formatCurrencyLocal(totalCashGiven)}</span>
            </div>
            {#if order.is_pos_order}
              <div class="total-row">
                <span>Terminal:</span>
                <span>POS System</span>
              </div>
            {/if}
          </div>

          <!-- Footer -->
          <div class="receipt-footer">
            <div class="dashed-line"></div>
            <div class="bold">Thank you for your purchase!</div>
            <div>Please retain this receipt</div>
            <div>for your records</div>
            {#if storeSettings?.business_hours}
              <div class="dashed-line"></div>
              <div>Business Hours:</div>
              <div>Mon-Fri: 9AM-5PM</div>
              <div>Sat: 9AM-1PM</div>
            {/if}
          </div>
        </div>
      </div>
      

      
      <div class="print-actions">
        <button class="btn btn-primary" on:click={printReceipt}>
          🖨️ Print Receipt
        </button>
        <button class="btn btn-secondary" on:click={onClose}>
          Cancel
        </button>
      </div>
    </div>
  </div>
</div>

<style>
  /* Component-specific modal overrides */
  .modal-content {
    background: white;
    max-width: 500px;
    width: 95vw;
    max-height: 90vh;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e9ecef;
  }

  .modal-header h3 {
    margin: 0;
    color: #333;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .print-btn-header {
    background: #2196f3;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    font-size: 0.9rem;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s;
  }

  .print-btn-header:hover {
    background: #1976d2;
    transform: translateY(-1px);
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #666;
    padding: 0;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    color: #333;
  }

  .modal-body {
    padding: 1.5rem;
    overflow-y: auto;
    flex: 1;
  }

  .receipt-preview {
    border: 2px dashed #ccc;
    padding: 1rem;
    margin-bottom: 1.5rem;
    background: #f8f9fa;
  }

  .thermal-receipt {
    font-family: 'Courier New', monospace;
    font-size: 19px;
    line-height: 1.4;
    width: 320px;
    margin: 0 auto;
    background: white;
    padding: 10px;
    color: black;
  }

  .receipt-header {
    text-align: center;
    border-bottom: 1px dashed #000;
    padding-bottom: 8px;
    margin-bottom: 8px;
  }

  .store-name {
    font-weight: bold;
    font-size: 23px;
    margin-bottom: 4px;
  }

  .store-info {
    font-size: 17px;
    line-height: 1.2;
  }

  .receipt-info {
    margin: 8px 0;
    font-size: 19px;
  }

  .items-section {
    border-bottom: 1px dashed #000;
    padding-bottom: 8px;
    margin-bottom: 8px;
  }

  .item-row {
    display: flex;
    justify-content: space-between;
    margin: 2px 0;
    font-size: 19px;
  }

  .item-name {
    flex: 1;
    padding-right: 8px;
  }

  .item-qty-price {
    white-space: nowrap;
  }

  .totals-section {
    border-bottom: 1px dashed #000;
    padding-bottom: 8px;
    margin-bottom: 8px;
  }

  .total-row {
    display: flex;
    justify-content: space-between;
    margin: 2px 0;
    font-size: 19px;
  }

  .final-total {
    font-weight: bold;
    font-size: 21px;
    border-top: 1px solid #000;
    padding-top: 4px;
    margin-top: 4px;
  }

  .payment-info {
    margin: 8px 0;
    font-size: 19px;
  }

  .receipt-footer {
    text-align: center;
    font-size: 17px;
    margin-top: 8px;
  }

  .dashed-line {
    border-top: 1px dashed #000;
    margin: 8px 0;
  }

  .center {
    text-align: center;
  }

  .bold {
    font-weight: bold;
  }

  .print-actions {
    display: flex;
    gap: 1rem;
    justify-content: center;
  }

  /* Receipt-specific button overrides */
  .btn-primary {
    background: #2196f3;
  }

  .btn-primary:hover {
    background: #1976d2;
  }
</style>