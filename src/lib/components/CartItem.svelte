<script lang="ts">
  import type { CartItem as CartItemType } from '$lib/types';
  import { cartStore } from '$lib/stores/cartStore';

  export let item: CartItemType;
  export let loading = false;
  
  async function updateQuantity(newQuantity: number) {
    await cartStore.updateQuantity(item.id, newQuantity);
  }
</script>

<div class="cart-item">
  <img src={item.image_url} alt={item.name} />
  <div class="cart-item-info">
    <div class="cart-item-name">{item.name}</div>
    <div class="cart-item-price">R{item.price} × {item.quantity}</div>
    <div class="cart-item-quantity">
      <button 
        class="quantity-btn" 
        aria-label="Decrease quantity" 
        on:click={() => updateQuantity(item.quantity - 1)}
        disabled={item.quantity <= 1 || loading}
      >-</button>
      <input
        type="number"
        min="1"
        class="quantity-input"
        bind:value={item.quantity}
        aria-label="Quantity"
        disabled={loading}
        on:change={(e) => updateQuantity(Number(e.currentTarget.value))}
      />
      <button 
        class="quantity-btn" 
        aria-label="Increase quantity" 
        on:click={() => updateQuantity(item.quantity + 1)}
        disabled={loading}
      >+</button>
    </div>
  </div>
  <button 
    on:click={() => cartStore.removeItem(item.id)} 
    class="remove-btn"
    aria-label={`Remove ${item.name} from cart`}
    disabled={loading}
  >×</button>
</div>

<style>
  .cart-item {
    display: flex;
    padding: 1rem 0;
    border-bottom: 1px solid #eee;
    position: relative;
  }

  .cart-item img {
    width: 60px;
    height: 60px;
    object-fit: cover;
    border-radius: 4px;
  }

  .cart-item-info {
    flex: 1;
    margin-left: 1rem;
  }

  .cart-item-name {
    font-weight: 500;
    margin-bottom: 0.25rem;
  }

  .cart-item-price {
    color: #666;
    font-size: 0.875rem;
  }

  .cart-item-quantity {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .quantity-btn,
  .remove-btn {
    background: none;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 0.25rem 0.5rem;
    cursor: pointer;
  }

  .quantity-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .quantity-input {
    width: 40px;
    text-align: center;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 0.25rem;
  }

  .remove-btn {
    position: absolute;
    top: 1rem;
    right: 0;
    padding: 0.25rem 0.5rem;
    font-size: 1.25rem;
    line-height: 1;
  }
</style> 