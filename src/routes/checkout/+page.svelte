<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { cartStore, selectedPosUser } from '$lib/stores/cartStore';
  import { createOrder, logPaymentToLedger, getUserBalance, updateOrderStatus } from '$lib/services/orderService';
  import { goto } from '$app/navigation';
  import type { CartItem } from '$lib/types';
  import type { PosUser } from '$lib/stores/cartStore';
  import type { GuestInfo } from '$lib/types/index';
  import { fade, slide } from 'svelte/transition';
  import { supabase } from '$lib/supabase';
  import { get } from 'svelte/store';
  
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
  
  // Check if user is logged in
  onMount(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      // Fetch profile to check for POS role
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
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
          name: user.user_metadata?.name || '',
          phone: user.user_metadata?.phone || '',
          address: user.user_metadata?.address || ''
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

    // If POS, require cashGiven
    if (!isGuest && posUser && posUser.id) {
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
    if (!isGuest && posUser && posUser.id) {
      const cash = Number(cashGiven) || 0;
      paymentAmount = Math.min(cash, total); // Only pay up to the order total
      overpayment = Math.max(0, cash - total); // Any extra is credit
      debt = total - paymentAmount;
      paymentUserId = posUser.id;
    }

    // Enforce: Cannot track debt for guest orders (no selected customer) only in POS mode
    if (isPosUser && useGuest && Number(cashGiven) < total) {
      error = 'Cannot track debt for guest orders. Please select or create a customer account.';
      return;
    }

    try {
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
        (!isGuest && posUser && posUser.id) ? posUser.id : undefined,
        paymentMethod,
        debt
      );

      if (result.success) {
        // If there is overpayment, log it as credit (not tied to order)
        if (!isGuest && posUser && posUser.id && overpayment > 0) {
          await logPaymentToLedger(posUser.id, overpayment, undefined, 'Overpayment credit at POS', paymentMethod);
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
        if (overpayment > 0) {
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
</script>

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
          <span>R{cartStore.getTotal($cartStore)}</span>
        </div>
        <div class="summary-row">
          <span>Items:</span>
          <span>{cartStore.getItemCount($cartStore)}</span>
        </div>
        {#if !isGuest}
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
        {/if}
        {#if !isGuest}
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
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  }
  
  .guest-info {
    margin-bottom: 2rem;
    padding-bottom: 1.5rem;
    border-bottom: 1px solid #eee;
  }

  .form-group {
    margin-bottom: 1rem;
  }

  .form-group label {
    display: block;
    margin-bottom: 0.5rem;
    color: #333;
    font-weight: 500;
  }

  .form-group input,
  .form-group textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 1rem;
    transition: border-color 0.2s;
  }

  .form-group input:focus,
  .form-group textarea:focus {
    outline: none;
    border-color: #007bff;
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

  .login-prompt button {
    background: none;
    border: none;
    color: #007bff;
    text-decoration: underline;
    font-weight: 500;
    cursor: pointer;
    padding: 0;
    font: inherit;
  }

  .login-prompt button:hover {
    text-decoration: none;
  }
  
  .cart-items {
    margin-top: 1rem;
  }
  
  .cart-item {
    display: flex;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #eee;
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
    background: #f0f0f0;
    border: 1px solid #ddd;
    width: 28px;
    height: 28px;
    border-radius: 6px;
    font-size: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background-color 0.2s;
  }
  
  .quantity-btn:hover:not(:disabled) {
    background: #e0e0e0;
  }
  
  .quantity-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .quantity-input {
    width: 40px;
    padding: 4px;
    border: 1px solid #ccc;
    border-radius: 6px;
    text-align: center;
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
    transition: background-color 0.2s;
    margin-left: 1rem;
  }
  
  .remove-btn:hover {
    background: #bd2130;
  }
  
  .payment-options {
    margin: 1rem 0;
  }
  
  .payment-option {
    display: flex;
    align-items: center;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    margin-bottom: 0.5rem;
    cursor: pointer;
    transition: background-color 0.2s;
  }
  
  .payment-option:hover {
    background: #f8f9fa;
  }
  
  .payment-option input {
    margin-right: 0.75rem;
  }
  
  .order-summary {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #eee;
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
    background: #28a745;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1.1rem;
    cursor: pointer;
    transition: background-color 0.2s;
    margin-top: 1rem;
  }
  
  .pay-button:hover:not(:disabled) {
    background: #218838;
  }
  
  .pay-button:disabled {
    background: #ccc;
    cursor: not-allowed;
  }
  
  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
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
  }

  .success-message {
    background: white;
    color: #155724;
    padding: 2rem;
    border-radius: 12px;
    font-size: 1.5rem;
    text-align: center;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    max-width: 90%;
    width: 400px;
  }

  .success-icon {
    font-size: 3rem;
    color: #28a745;
    margin: 1rem 0;
  }
  
  .selected-customer-info {
    background: #f8f9fa;
    border: 1px solid #eee;
    border-radius: 6px;
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    font-size: 1rem;
    color: #333;
  }
  
  .selected-customer-info.warning {
    background: #fff3cd;
    border: 1px solid #ffeeba;
    color: #856404;
  }
  
  @media (max-width: 768px) {
    .checkout-content {
      grid-template-columns: 1fr;
    }
    
    .payment-section {
      position: static;
    }
  }

  .link-btn {
    background: none;
    border: none;
    color: #007bff;
    text-decoration: underline;
    font-weight: 500;
    cursor: pointer;
    padding: 0;
    font: inherit;
  }
  .link-btn:hover {
    text-decoration: none;
  }
</style> 