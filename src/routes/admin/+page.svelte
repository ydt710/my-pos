<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase, makeUserAdmin } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Product } from '$lib/types';
  
    let products: Product[] = [];
    let loading = false;
    let error = '';
    let editing: Product | null = null;
    let newProduct: Partial<Product> = { 
      name: '', 
      price: 0, 
      image_url: '', 
      quantity: 1,
      category: 'flower' // Default category
    };
    let user: any = null;
    let isAdmin = false;
    let adminStatus = '';

    const categories = [
      { id: 'joints', name: 'Joints' },
      { id: 'concentrate', name: 'Concentrate' },
      { id: 'flower', name: 'Flower' },
      { id: 'edibles', name: 'Edibles' }
    ];
  
    // Check if user is admin
    onMount(async () => {
      const { data } = await supabase.auth.getUser();
      user = data.user;
      console.log('User data:', user);
      console.log('User metadata:', user?.user_metadata);
      isAdmin = !!user?.user_metadata?.is_admin;
      console.log('Is admin:', isAdmin);
      if (!user) goto('/login');
      if (!isAdmin) goto('/');
      await fetchProducts();
    });
  
    async function fetchProducts() {
      loading = true;
      const { data, error: err } = await supabase.from('products').select('*');
      loading = false;
      if (err) error = err.message;
      else products = data;
    }
  
    async function saveProduct() {
      loading = true;
      error = '';
      if (editing) {
        // Update
        const { error: err } = await supabase
          .from('products')
          .update(editing)
          .eq('id', editing.id);
        if (err) error = err.message;
        editing = null;
      } else {
        // Insert
        const { error: err } = await supabase.from('products').insert([newProduct]);
        if (err) error = err.message;
        newProduct = { 
          name: '', 
          price: 0, 
          image_url: '', 
          quantity: 1,
          category: 'flower'
        };
      }
      await fetchProducts();
      loading = false;
    }
  
    function editProduct(product: Product) {
      editing = { ...product };
    }
  
    async function deleteProduct(id: number) {
      if (!confirm('Delete this product?')) return;
      loading = true;
      await supabase.from('products').delete().eq('id', id);
      await fetchProducts();
      loading = false;
    }
  
    async function testMakeAdmin() {
      if (user) {
        const success = await makeUserAdmin(user.id);
        adminStatus = success ? 'Successfully made admin!' : 'Failed to make admin';
        if (success) {
          // Refresh the page to update admin status
          window.location.reload();
        }
      }
    }
  </script>
  
  <h1>Product CMS</h1>
  {#if error}
    <div class="error">{error}</div>
  {/if}
  {#if loading}
    <div>Loading...</div>
  {/if}
  
  <!-- Product Form -->
  <form on:submit|preventDefault={saveProduct}>
    <h2>{editing ? 'Edit Product' : 'Add Product'}</h2>
    {#if editing}
      <input bind:value={editing.name} placeholder="Name" required />
      <input type="number" min="0" bind:value={editing.price} placeholder="Price" required />
      <input bind:value={editing.image_url} placeholder="Image URL" required />
      <input type="number" min="0" bind:value={editing.quantity} placeholder="Quantity" required />
      <select bind:value={editing.category} required>
        {#each categories as category}
          <option value={category.id}>{category.name}</option>
        {/each}
      </select>
      <button type="submit" disabled={loading}>Update</button>
      <button type="button" on:click={() => editing = null}>Cancel</button>
    {:else}
      <input bind:value={newProduct.name} placeholder="Name" required />
      <input type="number" min="0" bind:value={newProduct.price} placeholder="Price" required />
      <input bind:value={newProduct.image_url} placeholder="Image URL" required />
      <input type="number" min="0" bind:value={newProduct.quantity} placeholder="Quantity" required />
      <select bind:value={newProduct.category} required>
        {#each categories as category}
          <option value={category.id}>{category.name}</option>
        {/each}
      </select>
      <button type="submit" disabled={loading}>Add</button>
    {/if}
  </form>
  
  <!-- Product List -->
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Price</th>
        <th>Image</th>
        <th>Qty</th>
        <th>Category</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {#each products as p}
        <tr>
          <td>{p.name}</td>
          <td>R{p.price}</td>
          <td><img src={p.image_url} alt={p.name} width="40" /></td>
          <td>{p.quantity}</td>
          <td>{categories.find(c => c.id === p.category)?.name || p.category}</td>
          <td>
            <button on:click={() => editProduct(p)}>Edit</button>
            <button on:click={() => deleteProduct(p.id)}>Delete</button>
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
  
  {#if !isAdmin}
    <div>
      <button on:click={testMakeAdmin}>Make Me Admin</button>
      {#if adminStatus}
        <p>{adminStatus}</p>
      {/if}
    </div>
  {/if}
  
  <style>
    form, table { margin: 2rem 0; }
    input, select { 
      margin: 0.5rem;
      padding: 0.5rem;
      border: 1px solid #ccc;
      border-radius: 4px;
    }
    select {
      min-width: 150px;
    }
    .error { color: red; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 0.5rem; }
    img { border-radius: 4px; }
    button {
      margin: 0.25rem;
      padding: 0.5rem 1rem;
      border: none;
      border-radius: 4px;
      background: #007bff;
      color: white;
      cursor: pointer;
    }
    button:hover {
      background: #0056b3;
    }
    button[disabled] {
      background: #ccc;
      cursor: not-allowed;
    }
  </style>