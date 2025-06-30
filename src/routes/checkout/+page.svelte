<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { cartStore, selectedPosUser, getTotal, getItemCount, pricedCart } from '$lib/stores/cartStore';
  import { createOrder, getUserBalance, updateOrderStatus } from '$lib/services/orderService';
  import { goto } from '$app/navigation';
  import type { CartItem } from '$lib/types/index';
  import type { PosUser } from '$lib/stores/cartStore';
  import type { GuestInfo } from '$lib/types/index';
  import { fade, slide } from 'svelte/transition';
  import { supabase } from '$lib/supabase';
  import { get } from 'svelte/store';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import ReceiptModal from '$lib/components/ReceiptModal.svelte';
  import { getStock } from '$lib/services/stockService';
  import { derived } from 'svelte/store';
  
  let loading = false;
  let error = '';
  let success = '';
  let paymentMethod = 'cash'; // Default payment method
  let isGuest = true;
  let isPosUser = false;
  let guestInfo: GuestInfo = {
    email: 'Guest@gmail.com',
    name: 'Guest',
    phone: '',
    address: ''
  };
  let cashGiven: number | '' = '';
  let userAvailableCredit: number | null = null;
  let userAvailableDebt: number | null = null;
  let selectedCustomer: PosUser = null;

  let extraCashOption: 'change' | 'credit' = 'change'; // default
  let creditUsed = 0; // Ensure creditUsed is always defined and a number
  let showReceiptModal = false;
  let completedOrder: any = null;
  let currentPosUser: any = null;
  
  // Check if user is logged in
  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      // Fetch profile to check for POS role and get user info
      const { data: profile } = await supabase
        .from('profiles')
        .select('role, display_name, phone_number, address')
        .eq('auth_user_id', user.id)
        .single();
      if (profile && profile.role === 'pos') {
        isPosUser = true;
        currentPosUser = profile;
      }
      isGuest = false;
      // Only pre-fill guestInfo if NOT POS user
      if (!isPosUser) {
        guestInfo = {
          email: user.email || '',
          name: profile?.display_name || '',
          phone: profile?.phone_number || '',
          address: profile?.address || ''
        };
      } else {
        guestInfo = {
          email: 'Guest@gmail.com',
          name: 'Guest',
          phone: '',
          address: ''
        };
      }
    }

    // If POS user selected, use balance from selectedPosUser if present
    const posUser = get(selectedPosUser);
    if (posUser && posUser.id) {
      userAvailableCredit = await getUserBalance(posUser.id);
    }

    // Always keep selectedCustomer in sync with selectedPosUser for POS
    selectedCustomer = posUser;
  });
  
  // Redirect if cart is empty
  $: if ($pricedCart.length === 0 && !success) {
    goto('/');
  }
  
  // Debounce utility
  function debounce<T extends (...args: any[]) => void>(fn: T, delay: number): T {
    let timeout: ReturnType<typeof setTimeout>;
    return ((...args: any[]) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => fn(...args), delay);
    }) as T;
  }

  // Debounced updateQuantity
  const debouncedUpdateQuantity = debounce(async (item: CartItem, newQuantity: number) => {
    const shopStock = await getStock(item.id, 'shop');
    if (newQuantity > shopStock) {
      cartStore.updateQuantity(item.id, shopStock);
    } else {
      cartStore.updateQuantity(item.id, newQuantity);
    }
  }, 300);

  function validateGuestInfo(): string | null {
    if (isGuest) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!guestInfo.email || !emailRegex.test(guestInfo.email)) {
        return 'Please enter a valid email address';
      }
      if (!guestInfo.name || guestInfo.name.trim().length < 2) {
        return 'Please enter your full name (minimum 2 characters)';
      }
      if (!guestInfo.phone || !/^\+?[\d\s-]{10,}$/.test(guestInfo.phone)) {
        return 'Please enter a valid phone number (minimum 10 digits)';
      }
      if (!guestInfo.address || guestInfo.address.trim().length < 10) {
        return 'Please enter your complete delivery address (minimum 10 characters)';
      }
    }
    return null;
  }
  
  async function processPayment() {
    if ($pricedCart.length === 0) return;
    error = '';

    // Validate guest info if user is not logged in
    const validationError = validateGuestInfo();
    if (validationError) {
      error = validationError;
      return;
    }

    // POS: Require a user to be selected if selectedPosUser is set (i.e. POS mode)
    const posUser = get(selectedPosUser);
    if (!isGuest && posUser && !posUser.id) {
      error = 'Please select a customer for this POS order.';
      return;
    }

    // Only require cashGiven for POS users
    if (isPosUser && posUser && posUser.id) {
      if (cashGiven === '' || isNaN(Number(cashGiven))) {
        error = 'Please enter the cash given by the customer.';
        return;
      }
    }

    loading = true;
    success = '';

    const total = getTotal($pricedCart);
    let paymentUserId = null;
    if (!isGuest && posUser && posUser.id) {
      paymentUserId = posUser.id;
    } else if (!isGuest) {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();
        if (profile && profile.id) {
          paymentUserId = profile.id;
        }
      }
    }
    if (isGuest) {
      error = 'Guest checkout is not supported in the new system. Please log in or select a customer.';
      loading = false;
      return;
    }
    if (!paymentUserId) {
      error = 'Could not determine user for this order. Please select a customer or log in again.';
      loading = false;
      return;
    }
    try {
      // Ensure cashGiven is always a valid number
      let cash = Number(cashGiven);
      if (isNaN(cash) || cash < 0) cash = 0;
      const items = $pricedCart.map(item => ({
        product_id: item.id,
        quantity: item.quantity,
        price: item.price
      }));

      // This call now matches the simpler, refactored RPC function
      const result = await createOrder(
        total,
        $pricedCart,
        isGuest ? guestInfo : undefined,
        paymentUserId,
        paymentMethod,
        cash,
        isPosUser,
        extraCashOption
      );

      if (result.success) {
        success = '🎉 Order placed successfully! Thank you for your purchase.';
        
        // Fetch the completed order for receipt if we have an orderId
        if (result.orderId && isPosUser) {
          // Fetch order details from database
          const { data: orderData } = await supabase
            .from('orders')
            .select(`
              *,
              order_items (*, products (*)),
              profiles!orders_user_id_fkey (display_name, email, phone_number, address)
            `)
            .eq('id', result.orderId)
            .single();
          
          if (orderData) {
            completedOrder = {
              ...orderData,
              user: orderData.profiles,
              pos_user: currentPosUser // Add current POS user info
            };
            
            // Update order note with POS user info if not already set
            if (currentPosUser && !orderData.note?.includes('POS User:')) {
              const noteUpdate = `${orderData.note || ''} | POS User: ${currentPosUser.display_name}`.trim();
              await supabase
                .from('orders')
                .update({ note: noteUpdate })
                .eq('id', result.orderId);
            }
            
            setTimeout(() => {
              showReceiptModal = true;
            }, 1000);
          }
        }
        
        // Refresh balance after order
        if (paymentUserId) {
          const refreshedBalance = await getUserBalance(paymentUserId);
          console.log('[CHECKOUT PATCH] Refreshed user balance after order:', refreshedBalance);
          userAvailableCredit = refreshedBalance;
        }
        cartStore.clearCart();
        console.log('[CHECKOUT PATCH] Cart cleared');
        cashGiven = '';
        selectedPosUser.set(null);
        console.log('[CHECKOUT PATCH] selectedPosUser cleared');
        
        // Only auto-redirect if not showing receipt modal
        if (!isPosUser) {
          setTimeout(() => {
            success = '';
            goto('/');
          }, 2000);
        }
      } else {
        error = result.error || 'Payment failed. Please try again.';
        console.log('[CHECKOUT PATCH] Payment failed:', error);
      }
    } catch (err) {
      console.error('Payment error:', err);
      error = 'An unexpected error occurred. Please try again.';
    } finally {
      loading = false;
      console.log('[CHECKOUT PATCH] processPayment finished.');
    }
  }

  // Remove expensive $: blocks for user balance and credit
  let startingCredit = 0;
  let remainingCredit = 0;
  let lastSelectedCustomerId: string | null = null;

  async function fetchUserBalanceSummary(userId: string) {
    const { data, error } = await supabase
      .rpc('get_user_balance_summary', { p_user_id: userId })
      .single();
    if (error) {
      console.error('Failed to fetch user balance summary:', error);
      return { credit: 0, debt: 0 };
    }
    return data;
  }

  const unsubscribe = selectedPosUser.subscribe(async (val) => {
    selectedCustomer = val;
    if (val && val.id) {
      userAvailableCredit = await getUserBalance(val.id);
      userAvailableDebt = Math.abs(Math.min(0, userAvailableCredit));
    } else {
      userAvailableCredit = 0;
      userAvailableDebt = 0;
    }
  });
  onDestroy(unsubscribe);

  // Set cashGiven to total by default when payment section is shown
  $: if (!isGuest && (!selectedCustomer || !selectedCustomer.id)) {
    // POS guest mode
    if ($pricedCart.length > 0) {
      const total = getTotal($pricedCart);
      if (cashGiven === '' || cashGiven === 0) {
        cashGiven = total;
      }
    }
  }

  $: cartItems = $pricedCart;
  $: orderTotal = getTotal(cartItems);
  $: cartCount = getItemCount(cartItems);
  $: floatChange = !isGuest && cashGiven !== '' ? Number(cashGiven) - orderTotal : 0;

  // Calculate totalPaid, overpayment, and update summary logic
  $: totalPaid = creditUsed + Number(cashGiven);
  $: overpayment = Math.max(0, totalPaid - orderTotal);
  $: netPaid = totalPaid;
  $: actualCredit = (extraCashOption === 'credit' && overpayment > 0) ? overpayment : 0;
  $: changeToGive = (extraCashOption === 'change' && overpayment > 0) ? overpayment : 0;
  $: expectedNewBalance = (userAvailableCredit ?? 0) - creditUsed + actualCredit + cashPaid - changeToGive - orderTotal;

  // Derived values for summary
  $: cashPaid = Number(cashGiven) || 0;
  $: outstandingDebt = Math.max(0, orderTotal - netPaid);

  // Robust summary logic for debt/credit/overpayment
  let summary = {
    debtPaid: 0,
    creditToAccount: 0,
    changeToGive: 0,
    newBalance: 0,
    startingBalance: 0,
    orderPaid: 0,
    order: 0
  };

  $: {
    const startingBalance = userAvailableCredit ?? 0;
    let cash = Number(cashGiven) || 0;
    let order = orderTotal || 0;
    let debtPaid = 0;
    let creditToAccount = 0;
    let changeToGive = 0;
    let newBalance = startingBalance;
    let orderPaid = 0;

    // Pay off debt first
    if (startingBalance < 0) {
      debtPaid = Math.min(cash, Math.abs(startingBalance));
      newBalance += debtPaid;
      cash -= debtPaid;
    }

    // Any remaining cash is for the order
    orderPaid = Math.min(cash, order);
    cash -= orderPaid;
    order -= orderPaid;

    // Subtract any remaining unpaid order from balance as new debt
    if (order > 0) {
      newBalance -= order;
    }

    // Any remaining cash is credited or given as change
    if (cash > 0) {
      if (extraCashOption === 'credit') {
        creditToAccount = cash;
        newBalance += creditToAccount;
      } else {
        changeToGive = cash;
      }
    }

    summary = {
      debtPaid,
      creditToAccount,
      changeToGive,
      newBalance,
      startingBalance,
      orderPaid,
      order: orderTotal
    };
  }

  function closeReceiptModal() {
    showReceiptModal = false;
    completedOrder = null;
    // Redirect to home after closing receipt
    setTimeout(() => {
      success = '';
      goto('/');
    }, 500);
  }
</script>

<StarryBackground />

<div class="checkout-container">
  <h1>Checkout</h1>
  
  {#if success}
    <div class="success-overlay" transition:fade>
      <div class="success-message" transition:slide>
        {success}
        <div class="success-icon">✓</div>
      </div>
    </div>
  {/if}
  
  {#if error}
    <div class="error-message" transition:fade>{error}</div>
  {/if}
  
  <div class="checkout-content">
    <div class="order-review">
      <h2>Order Review</h2>
      <div class="cart-items">
        {#each $pricedCart as item (item.id)}
          <div class="cart-item">
            <img src={item.image_url} alt={item.name} />
            <div class="item-details">
              <h3>{item.name}</h3>
              <p class="price">R{item.price} × {item.quantity}</p>
              <div class="quantity-controls">
                <button 
                  class="quantity-btn" 
                  on:click={() => debouncedUpdateQuantity(item, item.quantity - 1)}
                  disabled={item.quantity <= 1}
                >-</button>
                <input
                  type="number"
                  min="1"
                  class="quantity-input"
                  bind:value={item.quantity}
                  on:change={async (e) => debouncedUpdateQuantity(item, Number(e.currentTarget.value))}
                />
                <button 
                  class="quantity-btn" 
                  on:click={() => debouncedUpdateQuantity(item, item.quantity + 1)}
                  disabled={item.quantity >= 99}
                >+</button>
              </div>
            </div>
            <button 
              class="remove-btn"
              on:click={() => cartStore.removeItem(item.id)}
            >×</button>
          </div>
        {/each}
      </div>
    </div>
    
    <div class="payment-section">
      {#if isGuest}
        <div class="guest-info">
          <h2>Guest Information</h2>
          <div class="form-group">
            <label for="email">Email*</label>
            <input 
              type="email" 
              id="email" 
              bind:value={guestInfo.email} 
              placeholder="your@email.com"
              required
            />
          </div>
          <div class="form-group">
            <label for="name">Full Name*</label>
            <input 
              type="text" 
              id="name" 
              bind:value={guestInfo.name} 
              placeholder="John Doe"
              required
            />
          </div>
          <div class="form-group">
            <label for="phone">Phone Number*</label>
            <input 
              type="tel" 
              id="phone" 
              bind:value={guestInfo.phone} 
              placeholder="+1234567890"
              required
            />
          </div>
          <div class="form-group">
            <label for="address">Delivery Address*</label>
            <textarea 
              id="address" 
              bind:value={guestInfo.address} 
              placeholder="Enter your full delivery address"
              required
            ></textarea>
          </div>
          <p class="login-prompt">
            Already have an account? 
            <button type="button" class="link-btn" on:click={() => goto('/login?redirect=/checkout')}>Login here</button>
          </p>
        </div>
      {/if}

      <h2>Payment Method</h2>
      <div class="payment-options">
        <label class="payment-option">
          <input 
            type="radio" 
            name="payment" 
            value="cash" 
            bind:group={paymentMethod}
          />
          <span>Cash on Delivery</span>
        </label>
        <label class="payment-option">
          <input 
            type="radio" 
            name="payment" 
            value="card" 
            bind:group={paymentMethod}
          />
          <span>Credit/Debit Card</span>
        </label>
      </div>
      
      <div class="order-summary">
        <h3>Order Summary</h3>
        <div class="summary-row">
          <span>Subtotal:</span>
          <span>R{orderTotal}</span>
        </div>
        <div class="summary-row">
          <span>Items:</span>
          <span>{cartCount}</span>
        </div>
        {#if isPosUser}
          {#if selectedCustomer && selectedCustomer.id}
            <div class="selected-customer-info">
              <strong>Selected Customer:</strong><br>
              {selectedCustomer.name}
              {#if selectedCustomer.phone}
                <br>Phone: {selectedCustomer.phone}
              {/if}
              {#if selectedCustomer.email}
                <br>Email: {selectedCustomer.email}
              {/if}
            </div>
          {:else}
            <div class="selected-customer-info warning">
              <strong>No customer selected.</strong> Please select a customer in the cart sidebar.
            </div>
          {/if}
          <div class="form-group">
            <label for="cash-given">Cash Given</label>
            <input
              id="cash-given"
              type="number"
              min="0"
              step="0.01"
              bind:value={cashGiven}
              placeholder="Enter cash given by customer"
              required
            />
          </div>
          {#if isPosUser && selectedCustomer && selectedCustomer.id && cashPaid > orderTotal}
            <div class="form-group">
              <label>Extra Cash Handling:</label>
              <div class="extra-cash-options">
                <label>
                  <input
                    type="radio"
                    name="extra-cash"
                    value="change"
                    bind:group={extraCashOption}
                  />
                  Give Change
                </label>
                <label>
                  <input
                    type="radio"
                    name="extra-cash"
                    value="credit"
                    bind:group={extraCashOption}
                  />
                  Credit to Account
                </label>
              </div>
            </div>
          {/if}
          {#if selectedCustomer}
            <div>
              <strong>Credit:</strong> R{userAvailableCredit?.toFixed(2) ?? '0.00'} <br>
              <strong>Debt:</strong> R{userAvailableDebt?.toFixed(2) ?? '0.00'}
            </div>
          {/if}
          {#if startingCredit > 0}
            <div class="summary-row">
              <span>Starting Credit:</span>
              <span>R{startingCredit.toFixed(2)}</span>
            </div>
          {/if}
          {#if (userAvailableCredit ?? 0) < 0}
            <div class="summary-row" style="color: #dc3545;">
              <span>Starting Debt:</span>
              <span>R{Math.abs(userAvailableCredit ?? 0).toFixed(2)}</span>
            </div>
          {/if}
          {#if creditUsed > 0}
            <div class="summary-row">
              <span>Credit Used:</span>
              <span>R{creditUsed.toFixed(2)}</span>
            </div>
          {/if}
          {#if cashPaid > 0}
            <div class="summary-row">
              <span>Cash Paid:</span>
              <span>R{cashPaid.toFixed(2)}</span>
            </div>
          {/if}
          <div class="summary-row">
            <span>Net Paid:</span>
            <span>R{netPaid.toFixed(2)}</span>
          </div>
          {#if summary.debtPaid > 0}
            <div class="summary-row">
              <span>R{summary.debtPaid.toFixed(2)} will be used to pay off debt.</span>
            </div>
          {/if}
          {#if extraCashOption === 'credit' && summary.creditToAccount > 0}
            <div class="summary-row">
              <span>Credit to Account:</span>
              <span>R{summary.creditToAccount.toFixed(2)}</span>
            </div>
          {/if}
          {#if extraCashOption === 'change' && summary.changeToGive > 0}
            <div class="summary-row">
              <span>Change to Give:</span>
              <span>R{summary.changeToGive.toFixed(2)}</span>
            </div>
          {/if}
          <div class="summary-row">
            <span><strong>Expected New Balance:</strong></span>
            <span style="color: {summary.newBalance < 0 ? '#dc3545' : summary.newBalance > 0 ? '#28a745' : '#333'};">
              <strong>{summary.newBalance < 0 ? `Debt: R${Math.abs(summary.newBalance).toFixed(2)}` : summary.newBalance > 0 ? `Credit: R${summary.newBalance.toFixed(2)}` : 'R0.00'}</strong>
            </span>
          </div>
          <div class="summary-row">
            <span>User Balance:</span>
            <span style="color: {summary.newBalance < 0 ? '#dc3545' : summary.newBalance > 0 ? '#28a745' : '#333'};">
              {summary.newBalance < 0 ? `Debt: R${Math.abs(summary.newBalance).toFixed(2)}` : summary.newBalance > 0 ? `Credit: R${summary.newBalance.toFixed(2)}` : 'R0.00'}
            </span>
          </div>
        {/if}
      </div>
      
      <button 
        class="pay-button"
        on:click={processPayment}
        disabled={loading || $pricedCart.length === 0}
      >
        {#if loading}
          <span class="loading-spinner"></span>
          Processing...
        {:else}
          {paymentMethod === 'cash' ? 'Place Order' : 'Pay Now'}
        {/if}
      </button>
    </div>
  </div>
</div>

{#if showReceiptModal && completedOrder}
  <ReceiptModal 
    order={completedOrder} 
    onClose={closeReceiptModal}
  />
{/if}

<style>
  .checkout-container {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1rem;
    position: relative;
    z-index: 1;
  }
  
  h1 {
    text-align: center;
    margin-bottom: 2rem;
    
  }
  
  .checkout-content {
    display: grid;
    grid-template-columns: 1fr 400px;
    gap: 2rem;
  }
  
  .order-review, .payment-section {
    
    backdrop-filter: blur(10px);
    border-radius: 16px;
    padding: 1.5rem;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
  }
  
  .guest-info {
    margin-bottom: 2rem;
    padding-bottom: 1.5rem;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }

  /* Checkout-specific form overrides */
  .form-group input,
  .form-group textarea {
    background: rgba(255, 255, 255, 0.9);
  }

  .login-prompt {
    margin-top: 1rem;
    text-align: center;
    color: #666;
  }

  .link-btn {
    background: none;
    border: none;
    color: #2196f3;
    text-decoration: underline;
    font-weight: 500;
    cursor: pointer;
    padding: 0;
    font: inherit;
  }

  .link-btn:hover {
    text-decoration: none;
  }
  
  .cart-items {
    margin-top: 1rem;
  }
  
  .cart-item {
    display: flex;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
    background: rgba(255, 255, 255, 0.5);
    border-radius: 8px;
    margin-bottom: 0.5rem;
  }
  
  .cart-item img {
    width: 80px;
    height: 80px;
    object-fit: cover;
    border-radius: 8px;
    margin-right: 1rem;
  }
  
  .item-details {
    flex-grow: 1;
  }
  
  .item-details h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.1rem;
    color: #333;
  }
  
  .price {
    color: #66ff00;
    margin: 0.5rem 0;
  }
  
  .quantity-controls {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .quantity-btn {
    background: rgba(240, 240, 240, 0.9);
    border: 1px solid rgba(0, 0, 0, 0.1);
    width: 28px;
    height: 28px;
    border-radius: 6px;
    font-size: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .quantity-btn:hover:not(:disabled) {
    background: rgba(224, 224, 224, 0.9);
    transform: translateY(-1px);
  }
  
  .quantity-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .quantity-input {
    width: 40px;
    padding: 4px;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 6px;
    text-align: center;
    background: rgba(255, 255, 255, 0.9);
  }
  
  .remove-btn {
    background: #dc3545;
    color: white;
    border: none;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.2s;
    margin-left: 1rem;
  }
  
  .remove-btn:hover {
    background: #bd2130;
    transform: scale(1.1);
  }
  
  .payment-options {
    margin: 1rem 0;
  }
  
  .payment-option {
    display: flex;
    align-items: center;
    padding: 0.75rem;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    margin-bottom: 0.5rem;
    cursor: pointer;
    transition: all 0.2s;
    background: rgba(255, 255, 255, 0.5);
  }
  
  .payment-option:hover {
    background: rgba(248, 249, 250, 0.9);
    transform: translateY(-1px);
  }
  
  .payment-option input {
    margin-right: 0.75rem;
  }
  
  .order-summary {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid rgba(0, 0, 0, 0.1);
  }
  
  .summary-row {
    display: flex;
    justify-content: space-between;
    margin: 0.5rem 0;
    color: #666;
  }
  
  .pay-button {
    width: 100%;
    padding: 1rem;
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    margin-top: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }
  
  .pay-button:hover:not(:disabled) {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
  }
  
  .pay-button:disabled {
    background: #e0e0e0;
    cursor: not-allowed;
  }
  
  .error-message {
    background: rgba(248, 215, 218, 0.9);
    color: #721c24;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
    backdrop-filter: blur(4px);
  }
  
  .success-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    backdrop-filter: blur(4px);
  }

  .success-message {
    background: rgba(255, 255, 255, 0.95);
    color: #155724;
    padding: 2rem;
    border-radius: 16px;
    font-size: 1.5rem;
    text-align: center;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    max-width: 90%;
    width: 400px;
    border: 1px solid rgba(255, 255, 255, 0.2);
  }

  .success-icon {
    font-size: 3rem;
    color: #28a745;
    margin: 1rem 0;
  }
  
  .selected-customer-info {
    background: rgba(248, 249, 250, 0.9);
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    font-size: 1rem;
    color: #333;
  }
  
  .selected-customer-info.warning {
    background: rgba(255, 243, 205, 0.9);
    border: 1px solid rgba(255, 238, 186, 0.9);
    color: #856404;
  }

  .loading-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid #ffffff;
    border-radius: 50%;
    border-top-color: transparent;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  
  @media (max-width: 800px) {
    .checkout-content {
      grid-template-columns: 1fr;
    }
    
    .payment-section {
      position: static;
    }

    .checkout-container {
      padding: 1rem;
    }

    .order-review, .payment-section {
      padding: 1rem;
    }
  }

  .extra-cash-options {
    display: flex;
    gap: 1.5rem;
    margin-top: 0.5rem;
  }
  .extra-cash-options label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
    cursor: pointer;
  }
</style> 