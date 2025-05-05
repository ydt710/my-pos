<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import Navbar from '$lib/components/Navbar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  
  let menuVisible = false;
  let cartVisible = false;
  let cartButton: HTMLButtonElement;
  
  function toggleMenu() {
    menuVisible = !menuVisible;
  }
  
  function toggleCart() {
    cartVisible = !cartVisible;
  }
</script>

<!-- Navbar Component -->
<Navbar 
  bind:cartButton
  onCartToggle={toggleCart} 
  onMenuToggle={toggleMenu}
/>

<!-- Main Content Area -->
<main class="home-container">
  <div class="welcome-section">
    <h1>Welcome to Route 420</h1>
    <div class="content">
      <p class="tagline">Family-Grown Cannabis, Crafted with Care</p>
      <div class="message">
        <p>At Route 420, we're more than just a dispensary – we're a family-run farm dedicated to cultivating the finest cannabis products. Our journey began with a simple passion for quality and a commitment to sustainable farming practices.</p>
        <p>Every product in our store is grown, harvested, and processed with the same care and attention we give to our own family. We believe in transparency, quality, and the power of nature's gifts.</p>
        <p>Join us on this journey and experience the difference that family-grown cannabis can make.</p>
    </div>
      <a href="/products" class="explore-btn">Explore Our Products</a>
    </div>
    </div>
</main>

<!-- Side Menu Component -->
<SideMenu visible={menuVisible} toggleVisibility={toggleMenu} />

<style>
  .home-container {
    margin-top: 70px;
    min-height: calc(100vh - 70px);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
  }

  .welcome-section {
    max-width: 800px;
    text-align: center;
    padding: 2rem;
    background: white;
    border-radius: 16px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  }

  h1 {
    font-size: 2.5rem;
    color: #333;
    margin-bottom: 1rem;
    font-weight: 700;
  }

  .tagline {
    font-size: 1.5rem;
    color: #007bff;
    margin-bottom: 2rem;
    font-weight: 600;
  }

  .message {
    text-align: left;
    margin-bottom: 2rem;
  }

  .message p {
    font-size: 1.1rem;
    line-height: 1.6;
    color: #555;
    margin-bottom: 1rem;
  }
  
  .explore-btn {
    display: inline-block;
    padding: 1rem 2rem;
    background: #007bff;
    color: white;
    text-decoration: none;
    border-radius: 8px;
    font-weight: 600;
    transition: all 0.3s ease;
    border: none;
    cursor: pointer;
  }

  .explore-btn:hover {
    background: #0056b3;
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  }
  
  @media (max-width: 768px) {
    .welcome-section {
      padding: 1.5rem;
    }
    
    h1 {
      font-size: 2rem;
    }

    .tagline {
      font-size: 1.2rem;
    }
    
    .message p {
      font-size: 1rem;
    }
  }
</style>
