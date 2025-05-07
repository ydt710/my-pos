<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase, makeUserAdmin } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Product } from '$lib/types';
    import { makeUserAdmin as userServiceMakeUserAdmin } from '$lib/services/userService';
  
    let products: Product[] = [];
    let loading = true;
    let error = '';
    let success = '';
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
    let stats = {
      totalOrders: 0,
      totalRevenue: 0,
      topProducts: [] as { name: string; quantity: number; revenue: number }[],
      recentOrders: [] as any[]
    };
    let menuVisible = false;
    let cartVisible = false;
    let cartButton: HTMLButtonElement;

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
      await fetchStats();
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
        const success = await userServiceMakeUserAdmin(user.id);
        adminStatus = success ? 'Successfully made admin!' : 'Failed to make admin';
        if (success) {
          // Refresh the page to update admin status
          window.location.reload();
        }
      }
    }
  
    async function fetchStats() {
      try {
        // Fetch total orders and revenue
        const { data: ordersData, error: ordersError } = await supabase
          .from('orders')
          .select(`
            *,
            order_items (
              *,
              product:products (
                name,
                price
              )
            )
          `);

        if (ordersError) throw ordersError;

        // Calculate total orders and revenue
        stats.totalOrders = ordersData?.length || 0;
        stats.totalRevenue = ordersData?.reduce((total, order) => {
          return total + (order.order_items?.reduce((itemTotal: number, item: any) => {
            return itemTotal + (item.quantity * item.price);
          }, 0) || 0);
        }, 0) || 0;

        // Calculate top products
        const productStats = new Map();
        ordersData?.forEach(order => {
          order.order_items?.forEach((item: any) => {
            const key = item.product.name;
            if (!productStats.has(key)) {
              productStats.set(key, { quantity: 0, revenue: 0 });
            }
            const stats = productStats.get(key);
            stats.quantity += item.quantity;
            stats.revenue += item.quantity * item.price;
          });
        });

        stats.topProducts = Array.from(productStats.entries())
          .map(([name, data]) => ({
            name,
            quantity: data.quantity,
            revenue: data.revenue
          }))
          .sort((a, b) => b.revenue - a.revenue)
          .slice(0, 5);

        // Get recent orders with formatted IDs
        stats.recentOrders = ordersData
          ?.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
          .slice(0, 5)
          .map(order => ({
            ...order,
            shortId: `#${order.id.toString().padStart(4, '0')}`,
            username: 'Customer' // Temporarily use generic name until we fix the user relationship
          })) || [];

      } catch (err) {
        console.error('Error fetching stats:', err);
        error = 'Failed to load statistics';
      }
    }

    async function deleteAllOrders() {
      if (!confirm('WARNING: This will delete ALL orders and order items. This action cannot be undone. Are you sure?')) {
        return;
      }

      loading = true;
      error = '';

      try {
        // First delete all order items
        const { error: itemsError } = await supabase
          .from('order_items')
          .delete()
          .not('id', 'is', null); // This will delete all records

        if (itemsError) throw itemsError;

        // Then delete all orders
        const { error: ordersError } = await supabase
          .from('orders')
          .delete()
          .not('id', 'is', null); // This will delete all records

        if (ordersError) throw ordersError;

        // Refresh stats
        await fetchStats();
        success = 'All orders have been deleted successfully.';
      } catch (err) {
        console.error('Error deleting all orders:', err);
        error = 'Failed to delete orders. Please try again.';
      } finally {
        loading = false;
      }
    }
  </script>
  
  <div class="admin-container">
    <h1>Admin Dashboard</h1>

    {#if error}
      <div class="error">{error}</div>
    {/if}

    {#if success}
      <div class="success">{success}</div>
    {/if}

    <!-- Statistics Section -->
    <section class="stats-section">
      <div class="section-header">
        <h2>Sales Statistics</h2>
        <button 
          class="danger-btn" 
          on:click={deleteAllOrders}
          disabled={loading}
        >
          Delete All Orders
        </button>
      </div>
      <div class="stats-grid">
        <div class="stat-card">
          <h3>Total Orders</h3>
          <p class="stat-value">{stats.totalOrders}</p>
        </div>
        <div class="stat-card">
          <h3>Total Revenue</h3>
          <p class="stat-value">R{stats.totalRevenue.toFixed(2)}</p>
        </div>
      </div>

      <div class="stats-details">
        <div class="top-products">
          <h3>Top Selling Products</h3>
          <table>
            <thead>
              <tr>
                <th>Product</th>
                <th>Quantity Sold</th>
                <th>Revenue</th>
              </tr>
            </thead>
            <tbody>
              {#each stats.topProducts as product}
                <tr>
                  <td>{product.name}</td>
                  <td>{product.quantity}</td>
                  <td>R{product.revenue.toFixed(2)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <div class="recent-orders">
          <h3>Recent Orders</h3>
          <table>
            <thead>
              <tr>
                <th>Order ID</th>
                <th>Customer</th>
                <th>Date</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              {#each stats.recentOrders as order}
                <tr>
                  <td>{order.shortId}</td>
                  <td>{order.username}</td>
                  <td>{new Date(order.created_at).toLocaleDateString()}</td>
                  <td>R{order.total.toFixed(2)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- Existing Product Management Section -->
    <section class="product-management">
      <h2>Product Management</h2>
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
    </section>

    {#if !isAdmin}
      <div>
        <button on:click={testMakeAdmin}>Make Me Admin</button>
        {#if adminStatus}
          <p>{adminStatus}</p>
        {/if}
      </div>
    {/if}
  </div>
  
  <style>
    .admin-container {
      max-width: 1200px;
      margin: 2rem auto;
      padding: 0 1rem;
    }

    .stats-section {
      background: white;
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 2rem;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }

    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
      margin-bottom: 2rem;
    }

    .stat-card {
      background: #f8f9fa;
      padding: 1.5rem;
      border-radius: 8px;
      text-align: center;
    }

    .stat-card h3 {
      margin: 0 0 0.5rem;
      color: #666;
      font-size: 1rem;
    }

    .stat-value {
      margin: 0;
      font-size: 1.5rem;
      font-weight: 600;
      color: #333;
    }

    .stats-details {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 2rem;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 1rem;
    }

    th, td {
      padding: 0.75rem;
      text-align: left;
      border-bottom: 1px solid #eee;
    }

    th {
      font-weight: 600;
      color: #666;
      background: #f8f9fa;
    }

    .top-products, .recent-orders {
      background: #f8f9fa;
      padding: 1rem;
      border-radius: 8px;
    }

    .top-products h3, .recent-orders h3 {
      margin: 0 0 1rem;
      color: #333;
    }

    @media (max-width: 768px) {
      .stats-details {
        grid-template-columns: 1fr;
      }
    }

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

    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1.5rem;
    }

    .danger-btn {
      background: #dc3545;
      color: white;
      border: none;
      padding: 0.5rem 1rem;
      border-radius: 6px;
      cursor: pointer;
      transition: background-color 0.2s;
    }

    .danger-btn:hover:not(:disabled) {
      background: #bd2130;
    }

    .danger-btn:disabled {
      background: #ccc;
      cursor: not-allowed;
    }

    .success {
      background: #d4edda;
      color: #155724;
      padding: 1rem;
      border-radius: 8px;
      margin-bottom: 1rem;
    }
  </style>