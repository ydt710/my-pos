<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase, makeUserAdmin } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Product } from '$lib/types';
    import type { Order, OrderStatus, OrderFilters } from '$lib/types/orders';
    import { makeUserAdmin as userServiceMakeUserAdmin } from '$lib/services/userService';
    import { getAllOrders, updateOrderStatus } from '$lib/services/orderService';
    import { fade, slide } from 'svelte/transition';
    import OrderDetailsModal from '$lib/components/OrderDetailsModal.svelte';
  
    // Add Profile type
    interface Profile {
      id: string;
      email: string;
      display_name?: string;
    }
  
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
    let activeTab = 'products'; // Update to include 'orders'
    let orders: Order[] = [];
    let loadingOrders = false;
    let orderError: string | null = null;
    let selectedOrder: Order | null = null;
  
    let filters: OrderFilters = {
      status: undefined,
      dateFrom: undefined,
      dateTo: undefined,
      search: '',
      sortBy: 'created_at',
      sortOrder: 'desc'
    };
  
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
        // First, fetch orders with order items and products
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

        if (ordersError) {
          console.error('Error fetching orders:', ordersError);
          throw ordersError;
        }

        // If no orders exist yet, set default values
        if (!ordersData || ordersData.length === 0) {
          stats.totalOrders = 0;
          stats.totalRevenue = 0;
          stats.topProducts = [];
          stats.recentOrders = [];
          return;
        }

        // Then fetch profiles separately
        const userIds = ordersData.map(order => order.user_id).filter(Boolean);
        
        // If no valid user IDs, don't try to fetch profiles
        let profileMap = new Map();

        if (userIds.length > 0) {
          // Fetch profiles with proper error handling
          try {
            const { data: profilesData, error: profilesError } = await supabase
              .from('profiles')
              .select('id, email, display_name')
              .in('id', userIds);

            if (profilesError) throw profilesError;

            // Create a map of user profiles
            profileMap = new Map(
              (profilesData || []).map((profile: Profile) => [
                profile.id, 
                { 
                  ...profile,
                  // Fallback to email if no display name
                  display_name: profile.display_name || profile.email?.split('@')[0] || 'Unknown User'
                }
              ])
            );
          } catch (err) {
            console.error('Error fetching profiles:', err);
            // Continue with empty profile map rather than breaking the whole stats
            profileMap = new Map();
          }
        }

        // Calculate total orders and revenue
        stats.totalOrders = ordersData.length;
        stats.totalRevenue = ordersData.reduce((total, order) => {
          return total + (order.order_items?.reduce((itemTotal: number, item: any) => {
            return itemTotal + (item.quantity * item.price);
          }, 0) || 0);
        }, 0);

        // Calculate top products
        const productStats = new Map();
        ordersData.forEach(order => {
          order.order_items?.forEach((item: any) => {
            if (!item.product) return; // Skip if product is missing
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

        // Get recent orders with formatted IDs and customer names
        stats.recentOrders = ordersData
          .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
          .slice(0, 5)
          .map(order => {
            const profile = profileMap.get(order.user_id);
            
            // Use display name or fall back to email or Guest
            const username = profile
              ? profile.display_name || profile.email
              : 'Guest';

            return {
              ...order,
              shortId: `#${order.id.toString().padStart(4, '0')}`,
              username
            };
          });

      } catch (err) {
        console.error('Error fetching stats:', err);
        error = 'Failed to load statistics';
        // Set default values in case of error
        stats.totalOrders = 0;
        stats.totalRevenue = 0;
        stats.topProducts = [];
        stats.recentOrders = [];
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
  
    async function loadOrders() {
      loadingOrders = true;
      orderError = null;
      const { orders: fetchedOrders, error } = await getAllOrders(filters);
      if (error) {
        orderError = error;
      } else {
        orders = fetchedOrders;
      }
      loadingOrders = false;
    }
  
    async function handleStatusUpdate(orderId: string, newStatus: OrderStatus) {
      const { success, error } = await updateOrderStatus(orderId, newStatus);
      if (success) {
        await loadOrders(); // Refresh the list
        if (selectedOrder?.id === orderId) {
          selectedOrder.status = newStatus; // Update modal if open
        }
      } else {
        orderError = error;
      }
    }
  
    function formatDate(dateString: string) {
      return new Date(dateString).toLocaleString();
    }
  
    function getCustomerInfo(order: Order) {
      if (order.guest_info) {
        return {
          name: order.guest_info.name,
          email: order.guest_info.email,
          phone: order.guest_info.phone,
          address: order.guest_info.address
        };
      } else if (order.user) {
        // Try to get name from user_metadata first, then fallback to email username
        const name = order.user.user_metadata?.name || 
                     order.user.email?.split('@')[0] ||
                     'N/A';
        return {
          name: name,
          email: order.user.email || 'N/A',
          phone: order.user.user_metadata?.phone || 'N/A',
          address: order.user.user_metadata?.address || 'N/A'
        };
      }
      return {
        name: 'N/A',
        email: 'N/A',
        phone: 'N/A',
        address: 'N/A'
      };
    }
  
    $: if (activeTab === 'orders') {
      loadOrders();
    }
  </script>
  
  <div class="admin-container">
    <header class="admin-header">
        <h1>Admin Dashboard</h1>
        <div class="tabs">
            <button 
                class="tab-button" 
                class:active={activeTab === 'products'} 
                on:click={() => activeTab = 'products'}
            >
                Products
            </button>
            <button 
                class="tab-button" 
                class:active={activeTab === 'orders'} 
                on:click={() => activeTab = 'orders'}
            >
                Orders
            </button>
        </div>
    </header>

    {#if error}
        <div class="alert error" transition:fade>{error}</div>
    {/if}

    {#if success}
        <div class="alert success" transition:fade>{success}</div>
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
            <div class="stats-card">
                <h3>Top Selling Products</h3>
                <div class="table-container">
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
            </div>

            <div class="stats-card">
                <h3>Recent Orders</h3>
                <div class="table-container">
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
        </div>
    </section>

    <!-- Product Management Section -->
    {#if activeTab === 'products'}
        <section class="product-management">
            <div class="section-header">
                <h2>Product Management</h2>
            </div>
            
            <!-- Product Form -->
            <div class="form-card">
                <h3>{editing ? 'Edit Product' : 'Add Product'}</h3>
                <form on:submit|preventDefault={saveProduct}>
                    <div class="form-grid">
                        <div class="form-group">
                            <label for="name">Name</label>
                            {#if editing}
                                <input 
                                    id="name"
                                    bind:value={editing.name}
                                    placeholder="Product name" 
                                    required 
                                />
                            {:else}
                                <input 
                                    id="name"
                                    bind:value={newProduct.name}
                                    placeholder="Product name" 
                                    required 
                                />
                            {/if}
                        </div>
                        <div class="form-group">
                            <label for="price">Price</label>
                            {#if editing}
                                <input 
                                    id="price"
                                    type="number" 
                                    min="0" 
                                    step="0.01"
                                    bind:value={editing.price}
                                    placeholder="Price" 
                                    required 
                                />
                            {:else}
                                <input 
                                    id="price"
                                    type="number" 
                                    min="0" 
                                    step="0.01"
                                    bind:value={newProduct.price}
                                    placeholder="Price" 
                                    required 
                                />
                            {/if}
                        </div>
                        <div class="form-group">
                            <label for="image">Image URL</label>
                            {#if editing}
                                <input 
                                    id="image"
                                    bind:value={editing.image_url}
                                    placeholder="Image URL" 
                                    required 
                                />
                            {:else}
                                <input 
                                    id="image"
                                    bind:value={newProduct.image_url}
                                    placeholder="Image URL" 
                                    required 
                                />
                            {/if}
                        </div>
                        <div class="form-group">
                            <label for="quantity">Quantity</label>
                            {#if editing}
                                <input 
                                    id="quantity"
                                    type="number" 
                                    min="0" 
                                    bind:value={editing.quantity}
                                    placeholder="Quantity" 
                                    required 
                                />
                            {:else}
                                <input 
                                    id="quantity"
                                    type="number" 
                                    min="0" 
                                    bind:value={newProduct.quantity}
                                    placeholder="Quantity" 
                                    required 
                                />
                            {/if}
                        </div>
                        <div class="form-group">
                            <label for="category">Category</label>
                            {#if editing}
                                <select 
                                    id="category"
                                    bind:value={editing.category}
                                    required
                                >
                                    {#each categories as category}
                                        <option value={category.id}>{category.name}</option>
                                    {/each}
                                </select>
                            {:else}
                                <select 
                                    id="category"
                                    bind:value={newProduct.category}
                                    required
                                >
                                    {#each categories as category}
                                        <option value={category.id}>{category.name}</option>
                                    {/each}
                                </select>
                            {/if}
                        </div>
                    </div>
                    <div class="form-actions">
                        {#if editing}
                            <button type="submit" class="primary-btn" disabled={loading}>
                                Update Product
                            </button>
                            <button 
                                type="button" 
                                class="secondary-btn" 
                                on:click={() => editing = null}
                            >
                                Cancel
                            </button>
                        {:else}
                            <button type="submit" class="primary-btn" disabled={loading}>
                                Add Product
                            </button>
                        {/if}
                    </div>
                </form>
            </div>
            
            <!-- Product List -->
            <div class="table-card">
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Image</th>
                                <th>Name</th>
                                <th>Price</th>
                                <th>Quantity</th>
                                <th>Category</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {#each products as p}
                                <tr>
                                    <td>
                                        <img 
                                            src={p.image_url} 
                                            alt={p.name} 
                                            class="product-thumbnail"
                                        />
                                    </td>
                                    <td>{p.name}</td>
                                    <td>R{p.price}</td>
                                    <td>{p.quantity}</td>
                                    <td>{categories.find(c => c.id === p.category)?.name || p.category}</td>
                                    <td class="action-buttons">
                                        <button 
                                            class="edit-btn" 
                                            on:click={() => editProduct(p)}
                                        >
                                            Edit
                                        </button>
                                        <button 
                                            class="delete-btn" 
                                            on:click={() => deleteProduct(p.id)}
                                        >
                                            Delete
                                        </button>
                                    </td>
                                </tr>
                            {/each}
                        </tbody>
                    </table>
                </div>
            </div>
        </section>
    {/if}

    <!-- Orders Section -->
    {#if activeTab === 'orders'}
        <section class="orders-section" transition:fade>
            <div class="section-header">
                <h2>Order Management</h2>
            </div>
            
            {#if orderError}
                <div class="alert error" transition:fade>{orderError}</div>
            {/if}
            
            <div class="filters-card">
                <div class="filters">
                    <div class="filter-group">
                        <label for="status">Status</label>
                        <select id="status" bind:value={filters.status} on:change={loadOrders}>
                            <option value={undefined}>All</option>
                            <option value="pending">Pending</option>
                            <option value="processing">Processing</option>
                            <option value="completed">Completed</option>
                            <option value="cancelled">Cancelled</option>
                        </select>
                    </div>
                    
                    <div class="filter-group">
                        <label for="dateFrom">From</label>
                        <input 
                            type="date" 
                            id="dateFrom" 
                            bind:value={filters.dateFrom} 
                            on:change={loadOrders}
                        />
                    </div>
                    
                    <div class="filter-group">
                        <label for="dateTo">To</label>
                        <input 
                            type="date" 
                            id="dateTo" 
                            bind:value={filters.dateTo} 
                            on:change={loadOrders}
                        />
                    </div>
                    
                    <div class="filter-group">
                        <label for="search">Search</label>
                        <input 
                            type="text" 
                            id="search" 
                            placeholder="Search by email or name..." 
                            bind:value={filters.search} 
                            on:input={loadOrders}
                        />
                    </div>
                </div>
            </div>
            
            {#if loadingOrders}
                <div class="loading-spinner">Loading orders...</div>
            {:else}
                <div class="table-card">
                    <div class="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th>Order ID</th>
                                    <th>Date</th>
                                    <th>Customer</th>
                                    <th>Total</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {#each orders as order}
                                    {@const customer = getCustomerInfo(order)}
                                    <tr>
                                        <td>{order.id}</td>
                                        <td>{formatDate(order.created_at)}</td>
                                        <td>
                                            <div class="customer-info">
                                                <strong>{customer.name}</strong>
                                                <span>{customer.email}</span>
                                            </div>
                                        </td>
                                        <td>R{order.total}</td>
                                        <td>
                                            <select 
                                                value={order.status}
                                                class="status-select"
                                                class:pending={order.status === 'pending'}
                                                class:processing={order.status === 'processing'}
                                                class:completed={order.status === 'completed'}
                                                class:cancelled={order.status === 'cancelled'}
                                                on:change={(e) => handleStatusUpdate(order.id, e.currentTarget.value as OrderStatus)}
                                            >
                                                <option value="pending">Pending</option>
                                                <option value="processing">Processing</option>
                                                <option value="completed">Completed</option>
                                                <option value="cancelled">Cancelled</option>
                                            </select>
                                        </td>
                                        <td>
                                            <button 
                                                class="view-details-btn"
                                                on:click={() => selectedOrder = order}
                                            >
                                                View Details
                                            </button>
                                        </td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>
                </div>
            {/if}
        </section>
    {/if}

    {#if selectedOrder}
        <OrderDetailsModal
            order={selectedOrder}
            onClose={() => selectedOrder = null}
            onStatusUpdate={handleStatusUpdate}
        />
    {/if}
  </div>
  
  <style>
    .admin-container {
        max-width: 1400px;
        margin: 0 auto;
        padding: 2rem;
        background: #f8f9fa;
        min-height: 100vh;
    }

    .admin-header {
        margin-bottom: 2rem;
        text-align: center;
    }

    .admin-header h1 {
        margin: 0 0 1rem;
        color: #333;
        font-size: 2rem;
    }

    .tabs {
        display: flex;
        justify-content: center;
        gap: 1rem;
        margin-bottom: 2rem;
    }

    .tab-button {
        padding: 0.75rem 2rem;
        border: none;
        border-radius: 8px;
        background: #e9ecef;
        color: #495057;
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.2s;
    }

    .tab-button:hover {
        background: #dee2e6;
    }

    .tab-button.active {
        background: #007bff;
        color: white;
    }

    .alert {
        padding: 1rem;
        border-radius: 8px;
        margin-bottom: 1rem;
    }

    .error {
        background: #f8d7da;
        color: #721c24;
    }

    .success {
        background: #d4edda;
        color: #155724;
    }

    .section-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 1.5rem;
    }

    .section-header h2 {
        margin: 0;
        color: #333;
        font-size: 1.5rem;
    }

    .stats-section, .product-management, .orders-section {
        margin-bottom: 2rem;
    }

    .stats-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 1.5rem;
        margin-bottom: 2rem;
    }

    .stat-card {
        background: white;
        padding: 1.5rem;
        border-radius: 12px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        text-align: center;
    }

    .stat-card h3 {
        margin: 0 0 1rem;
        color: #6c757d;
        font-size: 1rem;
    }

    .stat-value {
        margin: 0;
        font-size: 2rem;
        font-weight: 600;
        color: #007bff;
    }

    .stats-details {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
        gap: 1.5rem;
    }

    .stats-card, .form-card, .table-card, .filters-card {
        background: white;
        border-radius: 12px;
        padding: 1.5rem;
        box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    }

    .table-container {
        overflow-x: auto;
    }

    table {
        width: 100%;
        border-collapse: collapse;
    }

    th, td {
        padding: 1rem;
        text-align: left;
        border-bottom: 1px solid #e9ecef;
    }

    th {
        background: #f8f9fa;
        color: #495057;
        font-weight: 600;
    }

    tr:hover {
        background: #f8f9fa;
    }

    .form-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1rem;
        margin-bottom: 1.5rem;
    }

    .form-group {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .form-group label {
        color: #495057;
        font-size: 0.9rem;
    }

    input, select {
        padding: 0.75rem;
        border: 1px solid #dee2e6;
        border-radius: 6px;
        font-size: 1rem;
        background: white;
    }

    input:focus, select:focus {
        outline: none;
        border-color: #007bff;
        box-shadow: 0 0 0 2px rgba(0,123,255,0.25);
    }

    .form-actions {
        display: flex;
        gap: 1rem;
        justify-content: flex-end;
    }

    .primary-btn, .secondary-btn, .danger-btn, .view-details-btn {
        padding: 0.75rem 1.5rem;
        border: none;
        border-radius: 6px;
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.2s;
    }

    .primary-btn {
        background: #007bff;
        color: white;
    }

    .primary-btn:hover {
        background: #0056b3;
    }

    .secondary-btn {
        background: #6c757d;
        color: white;
    }

    .secondary-btn:hover {
        background: #5a6268;
    }

    .danger-btn {
        background: #dc3545;
        color: white;
    }

    .danger-btn:hover:not(:disabled) {
        background: #c82333;
    }

    .danger-btn:disabled {
        background: #e9ecef;
        cursor: not-allowed;
    }

    .view-details-btn {
        background: #28a745;
        color: white;
    }

    .view-details-btn:hover {
        background: #218838;
    }

    .product-thumbnail {
        width: 50px;
        height: 50px;
        object-fit: cover;
        border-radius: 4px;
    }

    .action-buttons {
        display: flex;
        gap: 0.5rem;
    }

    .edit-btn, .delete-btn {
        padding: 0.5rem 1rem;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        transition: all 0.2s;
    }

    .edit-btn {
        background: #ffc107;
        color: #212529;
    }

    .edit-btn:hover {
        background: #e0a800;
    }

    .delete-btn {
        background: #dc3545;
        color: white;
    }

    .delete-btn:hover {
        background: #c82333;
    }

    .filters {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1rem;
    }

    .filter-group {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .filter-group label {
        color: #495057;
        font-size: 0.9rem;
    }

    .customer-info {
        display: flex;
        flex-direction: column;
        gap: 0.25rem;
    }

    .customer-info strong {
        color: #212529;
    }

    .customer-info span {
        color: #6c757d;
        font-size: 0.9rem;
    }

    .status-select {
        padding: 0.5rem;
        border-radius: 4px;
        border: 1px solid #dee2e6;
    }

    .status-select.pending {
        background: #fff3cd;
        color: #856404;
        border-color: #ffeeba;
    }

    .status-select.processing {
        background: #cce5ff;
        color: #004085;
        border-color: #b8daff;
    }

    .status-select.completed {
        background: #d4edda;
        color: #155724;
        border-color: #c3e6cb;
    }

    .status-select.cancelled {
        background: #f8d7da;
        color: #721c24;
        border-color: #f5c6cb;
    }

    .loading-spinner {
        text-align: center;
        padding: 2rem;
        color: #6c757d;
    }

    @media (max-width: 768px) {
        .admin-container {
            padding: 1rem;
        }

        .stats-details {
            grid-template-columns: 1fr;
        }

        .form-grid {
            grid-template-columns: 1fr;
        }

        .action-buttons {
            flex-direction: column;
        }

        .filters {
            grid-template-columns: 1fr;
        }
    }
  </style>