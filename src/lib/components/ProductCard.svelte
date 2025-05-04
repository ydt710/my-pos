<script lang="ts">
  import { onMount } from 'svelte';
  import type { Product } from '$lib/types';
  import { cartStore } from '$lib/stores/cartStore';
  
  export let product: Product;
  export let onAddToCart: (product: Product) => void;
  
  // Ensure quantity is always between 1 and 99
  $: if (product.quantity < 1) {
    product.quantity = 1;
  } else if (product.quantity > 99) {
    product.quantity = 99;
  }

  function handleQuantityChange(newQuantity: number) {
    product.quantity = Math.min(99, Math.max(1, newQuantity));
  }
</script>

<div class="product-card" tabindex="0" aria-label={`Product: ${product.name}`}>
  <img 
    src={product.image_url} 
    alt={product.name} 
    class="product-image" 
    loading="lazy"
  />
  <div class="product-info">
    <h3>{product.name}</h3>
    <p>R{product.price}</p>
    <div class="quantity-controls">
      <button 
        class="quantity-btn" 
        aria-label="Decrease quantity" 
        on:click={() => handleQuantityChange(product.quantity - 1)}
        disabled={product.quantity <= 1}
      >-</button>
      <input
        type="number"
        min="1"
        max="99"
        class="quantity-input"
        bind:value={product.quantity}
        aria-label="Quantity"
        on:change={(e) => handleQuantityChange(Number(e.currentTarget.value))}
      />
      <button 
        class="quantity-btn" 
        aria-label="Increase quantity" 
        on:click={() => handleQuantityChange(product.quantity + 1)}
        disabled={product.quantity >= 99}
      >+</button>
    </div>
    <button 
      on:click={() => onAddToCart(product)} 
      class="add-to-cart-btn"
      aria-label={`Add ${product.name} to cart`}
    >
      Add to Cart
    </button>
  </div>
</div>

<style>
  .product-card {
    background: white;
    border-radius: 12px;
    overflow: hidden;
    text-align: center;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    transition: transform 0.2s, box-shadow 0.2s;
    width: 100%;
    margin: 0 auto;
  }

  .product-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 6px 16px rgba(0,0,0,0.12);
  }

  .product-card:focus {
    outline: 2px solid #007bff;
    outline-offset: 2px;
  }

  .product-image {
    width: 100%;
    height: 250px;
    object-fit: cover;
  }

  .product-info {
    padding: 1.25rem;
  }

  .product-info h3 {
    margin: 0.5rem 0;
    font-size: 1.2rem;
    font-weight: 600;
    color: #333;
  }

  .product-info p {
    margin: 0.5rem 0 1.25rem;
    font-size: 1.1rem;
    color: #444;
    font-weight: 500;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1.25rem;
    gap: 0.5rem;
  }

  .quantity-btn {
    background: #f0f0f0;
    border: 1px solid #ddd;
    width: 32px;
    height: 32px;
    border-radius: 6px;
    font-size: 1.2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .quantity-btn:hover {
    background: #e0e0e0;
  }

  .quantity-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .quantity-input {
    width: 50px;
    padding: 6px;
    border: 1px solid #ccc;
    border-radius: 6px;
    text-align: center;
    font-size: 1.1rem;
    font-weight: 500;
  }

  .quantity-input::-webkit-inner-spin-button,
  .quantity-input::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .quantity-input {
    -moz-appearance: textfield;
  }

  .add-to-cart-btn {
    background: #007bff;
    border: none;
    color: white;
    padding: 10px 20px;
    border-radius: 30px;
    cursor: pointer;
    font-size: 1.1rem;
    font-weight: 500;
    width: 100%;
    transition: background-color 0.2s;
  }

  .add-to-cart-btn:hover {
    background: #0056b3;
  }

  .add-to-cart-btn:focus {
    outline: 2px solid #007bff;
    outline-offset: 2px;
  }

  @media (max-width: 1440px) {
    .product-info {
      padding: 1rem;
    }

    .product-info h3 {
      font-size: 1.1rem;
    }

    .product-info p {
      font-size: 1rem;
    }

    .quantity-btn {
      width: 30px;
      height: 30px;
      font-size: 1.1rem;
    }

    .quantity-input {
      width: 45px;
      font-size: 1rem;
    }

    .add-to-cart-btn {
      font-size: 1rem;
      padding: 8px 16px;
    }
  }

  @media (max-width: 768px) {
    .product-image {
      height: 200px;
    }

    .product-info {
      padding: 0.75rem;
    }

    .product-info h3 {
      font-size: 1rem;
    }

    .product-info p {
      font-size: 0.95rem;
    }

    .quantity-btn {
      width: 28px;
      height: 28px;
      font-size: 1rem;
    }

    .quantity-input {
      width: 40px;
      font-size: 0.95rem;
    }

    .add-to-cart-btn {
      font-size: 0.95rem;
      padding: 6px 12px;
    }
  }
</style> 