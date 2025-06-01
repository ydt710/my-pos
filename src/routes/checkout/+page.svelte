<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { cartStore, selectedPosUser } from '$lib/stores/cartStore';
  import { createOrder, logPaymentToLedger, getUserBalance, updateOrderStatus } from '$lib/services/orderService';
  import { goto } from '$app/navigation';
  import type { CartItem } from '$lib/types/index';
  import type { PosUser } from '$lib/stores/cartStore';
  import type { GuestInfo } from '$lib/types/index';
  import { fade, slide } from 'svelte/transition';
  import { supabase } from '$lib/supabase';
  import { get } from 'svelte/store';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  
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
  let posUserBalance: number | null = null;
  let selectedCustomer: PosUser = null;
  const FLOAT_USER_ID = '27cfee48-5b04-4ee1-885f-b3ef31417099'; // Float user for guest POS payments
  const FLOAT_USER_EMAIL = 'float@pos.local';
  let extraCashOption: 'change' | 'credit' = 'change'; // default
  let creditUsed = 0; // Ensure creditUsed is always defined and a number
  
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

    // If POS user selected, fetch their balance from the ledger
    const posUser = get(selectedPosUser);
    if (posUser && posUser.id) {
      posUserBalance = await getUserBalance(posUser.id);
    }

    // Clear float user if selected (e.g. from localStorage)
    const currentSelected = get(selectedPosUser);
    if (currentSelected && (currentSelected.id === FLOAT_USER_ID || currentSelected.email === FLOAT_USER_EMAIL)) {
      selectedPosUser.set(null);
    }
  });
  
  // Redirect if cart is empty
  $: if ($cartStore.length === 0 && !success) {
    goto('/');
  }
  
  function updateQuantity(item: CartItem, newQuantity: number) {
    cartStore.updateQuantity(item.id, newQuantity);
  }

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
    if ($cartStore.length === 0) return;
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

    const total = cartStore.getTotal($cartStore);

    // If POS mode and no customer selected, treat as guest
    const useGuest = isGuest || (!isGuest && (!posUser || !posUser.id));
    let debt = 0;
    let paymentAmount = 0;
    let paymentUserId = null;
    let overpayment = 0;
    let currentUserDebt = 0;
    let userProfileId = undefined;
    if (!isGuest && posUser && posUser.id) {
      // Fetch current user balance from ledger
      let userBalance = await getUserBalance(posUser.id);
      let userCredit = userBalance > 0 ? userBalance : 0;
      let userDebt = userBalance < 0 ? Math.abs(userBalance) : 0;
      let totalDue = Math.max(total + userDebt - userCredit, 0);
      creditUsed = Math.min(userCredit, total + userDebt);
      // If credit covers the whole order, set cashGiven to 0
      if (creditUsed >= total + userDebt) {
        cashGiven = 0;
      }
      const cash = Number(cashGiven) || 0;
      paymentAmount = Math.min(cash, totalDue); // Only pay up to the total due
      overpayment = Math.max(0, cash - totalDue);
      debt = totalDue - Math.min(cash, totalDue);
      paymentUserId = posUser.id;
      currentUserDebt = -userDebt; // For backend compatibility
    }

    // For regular logged-in users (not POS), fetch their profile id
    if (!isGuest && (!isPosUser || !posUser || !posUser.id)) {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const { data: profile, error: profileError } = await supabase
          .from('profiles')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();
        if (profile && profile.id) {
          userProfileId = profile.id;
        }
      }
    }

    // Enforce: Cannot track debt for guest orders (no selected customer) only in POS mode
    if (isPosUser && useGuest && Number(cashGiven) < total) {
      error = 'Cannot track debt for guest orders. Please select or create a customer account.';
      loading = false;
      return;
    }

    try {
      const cash = Number(cashGiven) || 0;
      // For guests, change is cash - total; for users, change/credit is only if cash > totalDue
      let change = 0;
      if (!isGuest && posUser && posUser.id) {
        const totalDue = total + Math.abs(currentUserDebt);
        change = extraCashOption === 'change' ? Math.max(0, cash - totalDue) : 0;
      } else {
        change = Math.max(0, cash - total);
      }
      const result = await createOrder(
        total,
        $cartStore,
        useGuest
          ? {
              ...guestInfo,
              email: guestInfo.email.toLowerCase().trim(),
              name: guestInfo.name.trim(),
              phone: guestInfo.phone.trim(),
              address: guestInfo.address.trim()
            }
          : undefined,
        (!isGuest && posUser && posUser.id)
          ? posUser.id
          : (!isGuest && userProfileId)
            ? userProfileId
            : undefined,
        paymentMethod,
        debt,
        cash,
        change,
        isPosUser && posUser && posUser.id ? true : false,
        extraCashOption,
        currentUserDebt,
        creditUsed
      );

      if (result.success) {
        // Log guest payments to float user if no customer is selected
        if ((!selectedCustomer || !selectedCustomer.id) && Number(cashGiven) > 0) {
          const cashInAmount = Math.min(Number(cashGiven), total);
          console.log('Logging guest payment to float user:', FLOAT_USER_ID, cashInAmount);
          await logPaymentToLedger(FLOAT_USER_ID, cashInAmount, result.orderId, 'Guest payment (float)', paymentMethod);
        }
        // Update order status to completed if POS user
        if (isPosUser && result.orderId) {
          const { success: statusSuccess, error: statusError } = await updateOrderStatus(result.orderId, 'completed');
          if (!statusSuccess) {
            console.error('Failed to update order status to completed:', statusError);
            // Optionally, show error to user
            error = 'Order placed, but failed to mark as completed.';
          }
        }
        // Update balance from ledger
        if (!isGuest && posUser && posUser.id) {
          posUserBalance = await getUserBalance(posUser.id);
        }
        success = '🎉 Order placed successfully! Thank you for your purchase.';
        if (overpayment > 0 && extraCashOption === 'credit') {
          success += ` (R${overpayment.toFixed(2)} credited to account)`;
        }
        if (isGuest) {
          success += ' We\'ll send your order details to ' + guestInfo.email;
        }
        cartStore.clearCart();
        cashGiven = '';
        // Clear selected POS user after order
        selectedPosUser.set(null);
        setTimeout(() => {
          success = '';
          goto('/');
        }, 5000);
      } else {
        error = result.error || 'Payment failed. Please try again.';
        if (error.includes('quantity') || error.includes('stock')) {
          await Promise.all($cartStore.map(async (item) => {
            const { data } = await supabase
              .from('products')
              .select('quantity')
              .eq('id', item.id)
              .single();
            if (data && data.quantity < item.quantity) {
              cartStore.updateQuantity(item.id, data.quantity);
            }
          }));
        }
      }
    } catch (err) {
      console.error('Payment error:', err);
      error = 'An unexpected error occurred. Please try again.';
    } finally {
      loading = false;
    }
  }

  // Watch for POS user change and update balance from ledger
  $: {
    const posUser = get(selectedPosUser);
    if (posUser && posUser.id) {
      getUserBalance(posUser.id).then(balance => {
        posUserBalance = balance;
      });
    } else {
      posUserBalance = null;
    }
  }

  // Optionally, subscribe to selectedPosUser for reactivity
  const unsubscribe = selectedPosUser.subscribe((val) => { selectedCustomer = val; });
  onDestroy(unsubscribe);

  // Set cashGiven to total by default when payment section is shown
  $: if (!isGuest && (!selectedCustomer || !selectedCustomer.id)) {
    // POS guest mode
    if ($cartStore.length > 0) {
      const total = cartStore.getTotal($cartStore);
      if (cashGiven === '' || cashGiven === 0) {
        cashGiven = total;
      }
    }
  }

  $: orderTotal = cartStore.getTotal($cartStore);
  $: floatChange = !isGuest && cashGiven !== '' ? Number(cashGiven) - orderTotal : 0;

  // Derived values for summary
  $: cashPaid = Number(cashGiven) || 0;
  $: netPaid = cashPaid + creditUsed;
  $: outstandingDebt = Math.max(0, orderTotal - netPaid);

  // Track starting and remaining credit for POS user
  let startingCredit = 0;
  let remainingCredit = 0;

  $: if (!isGuest && selectedCustomer && selectedCustomer.id && $cartStore.length > 0) {
    getUserBalance(selectedCustomer.id).then(userBalance => {
      startingCredit = userBalance > 0 ? userBalance : 0;
      const userDebt = userBalance < 0 ? Math.abs(userBalance) : 0;
      creditUsed = Math.min(startingCredit, orderTotal + userDebt);
      remainingCredit = Math.max(0, startingCredit - creditUsed);
      // If credit covers the whole order, set cashGiven to 0
      if (creditUsed >= orderTotal + userDebt) {
        cashGiven = 0;
      }
    });
  } else {
    creditUsed = 0;
    startingCredit = 0;
    remainingCredit = 0;
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
        {#each $cartStore as item}
          <div class="cart-item">
            <img src={item.image_url} alt={item.name} />
            <div class="item-details">
              <h3>{item.name}</h3>
              <p class="price">R{item.price} × {item.quantity}</p>
              <div class="quantity-controls">
                <button 
                  class="quantity-btn" 
                  on:click={() => updateQuantity(item, item.quantity - 1)}
                  disabled={item.quantity <= 1}
                >-</button>
                <input
                  type="number"
                  min="1"
                  max="99"
                  class="quantity-input"
                  bind:value={item.quantity}
                  on:change={(e) => updateQuantity(item, Number(e.currentTarget.value))}
                />
                <button 
                  class="quantity-btn" 
                  on:click={() => updateQuantity(item, item.quantity + 1)}
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
          <span>{cartStore.getItemCount($cartStore)}</span>
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
          {#if startingCredit > 0}
            <div class="summary-row">
              <span>Starting Credit:</span>
              <span>R{startingCredit.toFixed(2)}</span>
            </div>
          {/if}
          {#if creditUsed > 0}
            <div class="summary-row">
              <span>Credit Used:</span>
              <span>R{creditUsed.toFixed(2)}</span>
            </div>
          {/if}
          {#if remainingCredit > 0}
            <div class="summary-row">
              <span>Remaining Credit:</span>
              <span>R{remainingCredit.toFixed(2)}</span>
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
          {#if outstandingDebt > 0}
            <div class="summary-row" style="color: #dc3545;">
              <span>Outstanding Debt:</span>
              <span>R{outstandingDebt.toFixed(2)}</span>
            </div>
          {/if}
          {#if floatChange > 0 && creditUsed === 0}
            <div class="summary-row" style="color: #28a745;">
              <span>Change to Give:</span>
              <span>R{floatChange.toFixed(2)}</span>
            </div>
          {/if}
          <div class="summary-row">
            <span>Balance:</span>
            <span style="color: {(posUserBalance ?? 0) > 0 ? '#28a745' : (posUserBalance ?? 0) < 0 ? '#dc3545' : '#666'};">
              R{posUserBalance ?? 0}
            </span>
          </div>
        {/if}
      </div>
      
      <button 
        class="pay-button"
        on:click={processPayment}
        disabled={loading || $cartStore.length === 0}
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
    color: #333;
  }
  
  .checkout-content {
    display: grid;
    grid-template-columns: 1fr 400px;
    gap: 2rem;
  }
  
  .order-review, .payment-section {
    background: rgba(255, 255, 255, 0.9);
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

  .form-group {
    margin-bottom: 1rem;
  }

  .form-group label {
    display: block;
    margin-bottom: 0.5rem;
    color: #555;
    font-weight: 500;
  }

  .form-group input,
  .form-group textarea {
    width: 100%;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    font-size: 1rem;
    transition: all 0.2s;
    background: rgba(255, 255, 255, 0.9);
  }

  .form-group input:focus,
  .form-group textarea:focus {
    outline: none;
    border-color: #2196f3;
    box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
  }

  .form-group textarea {
    min-height: 100px;
    resize: vertical;
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
    color: #666;
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
</style> 