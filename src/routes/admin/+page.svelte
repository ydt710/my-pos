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
    let imageFile: File | null = null;
    let uploadProgress = 0;
    let isUploading = false;
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
  
    let statsInterval: ReturnType<typeof setInterval>;
  
    let showImageModal = false;
    let tempImageUrl = '';
    let activeImageTab = 'upload'; // 'upload' or 'url'
  
    onMount(() => {
      // Check if user is admin
      supabase.auth.getUser().then(({ data }) => {
        user = data.user;
        isAdmin = !!user?.user_metadata?.is_admin;
        
        if (!user) goto('/login');
        if (!isAdmin) goto('/');
        
        // Initial load
        Promise.all([
          fetchProducts(),
          fetchStats()
        ]).catch(console.error);
        
        // Set up auto-refresh
        statsInterval = setInterval(fetchStats, 30000);
      });
      
      return () => {
        if (statsInterval) clearInterval(statsInterval);
      };
    });
  
    async function fetchProducts() {
      loading = true;
      const { data, error: err } = await supabase.from('products').select('*');
      loading = false;
      if (err) error = err.message;
      else products = data;
    }
  
    async function handleImageUpload(event: Event) {
        const input = event.target as HTMLInputElement;
        if (!input.files?.length) return;
        
        const file = input.files[0];
        if (!file) return;
        
        // Validate file type
        if (!file.type.startsWith('image/')) {
            error = 'Please upload an image file';
            return;
        }
        
        // Validate file size (max 5MB)
        if (file.size > 5 * 1024 * 1024) {
            error = 'Image size should be less than 5MB';
            return;
        }
        
        imageFile = file;
        
        // If you want to show a preview
        if (editing) {
            editing.image_url = URL.createObjectURL(file);
        } else {
            newProduct.image_url = URL.createObjectURL(file);
        }
    }
  
    async function uploadImageToStorage(file: File): Promise<string> {
        isUploading = true;
        uploadProgress = 0;
        
        try {
            const fileExt = file.name.split('.').pop();
            const fileName = `${Date.now()}.${fileExt}`;
            const filePath = `product-images/${fileName}`;
            
            const { data, error: uploadError } = await supabase.storage
                .from('products')
                .upload(filePath, file, {
                    cacheControl: '3600',
                    upsert: false
                });
                
            if (uploadError) throw uploadError;
            
            // Get the public URL
            const { data: { publicUrl } } = supabase.storage
                .from('products')
                .getPublicUrl(filePath);
                
            uploadProgress = 100;
            return publicUrl;
        } catch (err) {
            console.error('Error uploading image:', err);
            throw err;
        } finally {
            isUploading = false;
        }
    }
  
    async function saveProduct() {
        loading = true;
        error = '';
        try {
            let imageUrl = editing ? editing.image_url : newProduct.image_url;
            
            // If there's a new file to upload
            if (imageFile) {
                try {
                    imageUrl = await uploadImageToStorage(imageFile);
                } catch (err) {
                    error = 'Failed to upload image. Please try again.';
                    loading = false;
                    return;
                }
            }
            
            if (editing) {
                // Update
                const { error: err } = await supabase
                    .from('products')
                    .update({ ...editing, image_url: imageUrl })
                    .eq('id', editing.id);
                if (err) error = err.message;
                editing = null;
            } else {
                // Insert
                const { error: err } = await supabase
                    .from('products')
                    .insert([{ ...newProduct, image_url: imageUrl }]);
                if (err) error = err.message;
                newProduct = { 
                    name: '', 
                    price: 0, 
                    image_url: '', 
                    quantity: 1,
                    category: 'flower'
                };
            }
            
            // Reset file input
            imageFile = null;
            uploadProgress = 0;
            
            await fetchProducts();
        } catch (err) {
            console.error('Error saving product:', err);
            error = 'An unexpected error occurred';
        } finally {
            loading = false;
        }
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
          `)
          .order('created_at', { ascending: false });

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

        // Get unique user IDs from orders
        const userIds = ordersData
          .filter(order => order.user_id)
          .map(order => order.user_id);

        // Fetch profiles for registered users
        let profilesMap = new Map();
        if (userIds.length > 0) {
          const { data: profiles, error: profilesError } = await supabase
            .from('profiles')
            .select('id, email, display_name')
            .in('id', userIds);

          if (profilesError) {
            console.error('Error fetching profiles:', profilesError);
          } else if (profiles) {
            profilesMap = new Map(
              profiles.map(profile => [profile.id, profile])
            );
          }
        }

        // Calculate total orders and revenue
        stats.totalOrders = ordersData.length;
        stats.totalRevenue = ordersData.reduce((total, order) => {
          return total + (order.total || 0);
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
          .slice(0, 5)
          .map(order => {
            let username;
            if (order.guest_info) {
              username = `${order.guest_info.name} (Guest)`;
            } else if (order.user_id && profilesMap.has(order.user_id)) {
              const profile = profilesMap.get(order.user_id);
              username = profile.display_name || profile.email.split('@')[0];
            } else {
              username = 'Unknown';
            }

            return {
              ...order,
              shortId: order.order_number || `#${order.id.toString().padStart(4, '0')}`,
              username
            };
          });

        console.log('Stats updated:', {
          totalOrders: stats.totalOrders,
          totalRevenue: stats.totalRevenue,
          recentOrders: stats.recentOrders.map(o => ({
            id: o.shortId,
            username: o.username,
            isGuest: !!o.guest_info
          }))
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
  
    function handleImageSubmit() {
        if (activeImageTab === 'url' && tempImageUrl) {
            if (editing) {
                editing.image_url = tempImageUrl;
            } else {
                newProduct.image_url = tempImageUrl;
            }
            showImageModal = false;
            tempImageUrl = '';
        }
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
                            <label for="image">Product Image</label>
                            <div class="image-input-container">
                                {#if (editing?.image_url || newProduct.image_url)}
                                    <div class="image-preview">
                                        <img 
                                            src={editing ? editing.image_url : newProduct.image_url} 
                                            alt="Product preview" 
                                            class="preview-image"
                                        />
                                    </div>
                                {/if}
                                <button 
                                    type="button" 
                                    class="image-btn"
                                    on:click={() => {
                                        showImageModal = true;
                                        tempImageUrl = (editing ? editing.image_url : newProduct.image_url) || '';
                                    }}
                                >
                                    Add Image
                                </button>
                            </div>
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

    {#if showImageModal}
        <div class="modal-backdrop" on:click={() => showImageModal = false}>
            <div class="modal-content" on:click|stopPropagation>
                <h3>Add Product Image</h3>
                
                <div class="modal-tabs">
                    <button 
                        class="tab-btn" 
                        class:active={activeImageTab === 'upload'}
                        on:click={() => activeImageTab = 'upload'}
                    >
                        Upload Image
                    </button>
                    <button 
                        class="tab-btn" 
                        class:active={activeImageTab === 'url'}
                        on:click={() => activeImageTab = 'url'}
                    >
                        Image URL
                    </button>
                </div>

                {#if activeImageTab === 'upload'}
                    <div class="upload-area">
                        <label for="modal-image-upload" class="upload-label">
                            <div class="upload-icon">📁</div>
                            <span>Click to upload or drag and drop</span>
                            <span class="upload-hint">PNG, JPG up to 5MB</span>
                            <input 
                                type="file"
                                id="modal-image-upload"
                                accept="image/*"
                                on:change={handleImageUpload}
                                class="file-input"
                            />
                        </label>
                        {#if isUploading}
                            <div class="upload-progress">
                                <div 
                                    class="progress-bar" 
                                    style="width: {uploadProgress}%"
                                ></div>
                            </div>
                        {/if}
                    </div>
                {:else}
                    <form on:submit|preventDefault={handleImageSubmit}>
                        <div class="modal-form-group">
                            <input 
                                type="url"
                                bind:value={tempImageUrl}
                                placeholder="https://example.com/image.jpg"
                                autofocus
                            />
                        </div>
                        <div class="modal-actions">
                            <button type="submit" class="submit-btn">
                                Add Image
                            </button>
                        </div>
                    </form>
                {/if}

                <button 
                    type="button" 
                    class="close-btn" 
                    on:click={() => showImageModal = false}
                >
                    ×
                </button>
            </div>
        </div>
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
        overflow-x: auto;
        max-height: 400px;
        overflow-y: auto;
    }

    .table-container {
        overflow-x: auto;
        max-height: 400px;
        overflow-y: auto;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        min-width: 600px;
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

    .image-input-container {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        align-items: center;
    }

    .image-preview {
        width: 100%;
        max-width: 300px;
        height: 200px;
        border: 2px dashed #dee2e6;
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        overflow: hidden;
        background: #f8f9fa;
        margin: 0 auto;
    }

    .preview-image {
        max-width: 100%;
        max-height: 100%;
        object-fit: contain;
    }

    .image-upload-options {
        width: 100%;
        max-width: 300px;
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .upload-buttons {
        display: flex;
        gap: 0.5rem;
    }

    .upload-btn, .url-btn {
        flex: 1;
        padding: 0.75rem;
        border: none;
        border-radius: 6px;
        font-size: 0.9rem;
        cursor: pointer;
        transition: all 0.2s;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
    }

    .upload-btn {
        background: #007bff;
        color: white;
    }

    .upload-btn:hover {
        background: #0056b3;
    }

    .url-btn {
        background: #6c757d;
        color: white;
    }

    .url-btn:hover {
        background: #5a6268;
    }

    .file-input {
        position: absolute;
        width: 0.1px;
        height: 0.1px;
        opacity: 0;
        overflow: hidden;
        z-index: -1;
    }

    .upload-progress {
        width: 100%;
        height: 4px;
        background: #dee2e6;
        border-radius: 2px;
        overflow: hidden;
    }

    .progress-bar {
        height: 100%;
        background: #28a745;
        transition: width 0.3s ease;
    }

    @media (max-width: 768px) {
        .admin-container {
            padding: 0.5rem;
        }

        .stats-details {
            grid-template-columns: 1fr;
        }

        .stats-card, .form-card, .table-card, .filters-card {
            margin-bottom: 1rem;
            padding: 1rem;
            max-height: none;
            overflow: visible;
        }

        .table-container {
            max-height: none;
            overflow-y: visible;
            margin: 0 -1rem;
            padding: 0 1rem;
        }

        .table-responsive {
            display: block;
            width: 100%;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            -ms-overflow-style: -ms-autohiding-scrollbar;
        }

        .stats-card table {
            min-width: unset;
        }

        .stats-card tr {
            display: flex;
            flex-direction: column;
            padding: 0.5rem 0;
            border-bottom: 1px solid #dee2e6;
        }

        .stats-card td {
            padding: 0.25rem 0;
            border: none;
            text-align: left;
        }

        .stats-card th {
            display: none;
        }

        .form-grid {
            grid-template-columns: 1fr;
            gap: 0.75rem;
        }

        input, select, textarea {
            width: 100%;
            max-width: none;
        }

        .filters {
            grid-template-columns: 1fr;
            gap: 0.75rem;
        }

        .action-buttons {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }

        .action-buttons button {
            width: 100%;
        }

        .status-select {
            width: 100%;
            max-width: none;
        }

        .product-thumbnail {
            width: 40px;
            height: 40px;
        }

        .modal-content {
            padding: 1rem;
            width: 95%;
        }

        .tab-button {
            padding: 0.75rem 1rem;
        }

        .stat-card {
            padding: 1rem;
        }

        .stat-value {
            font-size: 1.5rem;
        }

        .customer-info {
            flex-direction: column;
            gap: 0.25rem;
        }

        .section-header {
            flex-direction: column;
            gap: 1rem;
            align-items: stretch;
            text-align: center;
        }

        .section-header button {
            width: 100%;
        }
    }

    .modal-backdrop {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
    }

    .modal-content {
        background: white;
        padding: 2rem;
        border-radius: 12px;
        width: 90%;
        max-width: 500px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }

    .modal-content h3 {
        margin: 0 0 1.5rem;
        color: #333;
        font-size: 1.25rem;
    }

    .modal-form-group {
        margin-bottom: 1.5rem;
    }

    .modal-form-group input {
        width: 100%;
        padding: 0.75rem;
        border: 1px solid #dee2e6;
        border-radius: 6px;
        font-size: 1rem;
    }

    .modal-form-group input:focus {
        outline: none;
        border-color: #007bff;
        box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.25);
    }

    .modal-actions {
        display: flex;
        justify-content: flex-end;
        gap: 1rem;
    }

    .cancel-btn, .submit-btn {
        padding: 0.75rem 1.5rem;
        border: none;
        border-radius: 6px;
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.2s;
    }

    .cancel-btn {
        background: #e9ecef;
        color: #495057;
    }

    .cancel-btn:hover {
        background: #dee2e6;
    }

    .submit-btn {
        background: #007bff;
        color: white;
    }

    .submit-btn:hover {
        background: #0056b3;
    }

    .image-btn {
        width: 100%;
        max-width: 300px;
        padding: 0.75rem;
        background: #007bff;
        color: white;
        border: none;
        border-radius: 6px;
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.2s;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
    }

    .image-btn:hover {
        background: #0056b3;
    }

    .modal-tabs {
        display: flex;
        gap: 1rem;
        margin-bottom: 1.5rem;
        border-bottom: 1px solid #dee2e6;
        padding-bottom: 1rem;
    }

    .tab-btn {
        padding: 0.5rem 1rem;
        background: none;
        border: none;
        color: #6c757d;
        cursor: pointer;
        font-size: 1rem;
        transition: all 0.2s;
        border-bottom: 2px solid transparent;
        margin-bottom: -1rem;
    }

    .tab-btn.active {
        color: #007bff;
        border-bottom-color: #007bff;
    }

    .upload-area {
        border: 2px dashed #dee2e6;
        border-radius: 8px;
        padding: 2rem;
        text-align: center;
        cursor: pointer;
        transition: all 0.2s;
    }

    .upload-area:hover {
        border-color: #007bff;
        background: #f8f9fa;
    }

    .upload-label {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 0.5rem;
        cursor: pointer;
    }

    .upload-icon {
        font-size: 2rem;
        margin-bottom: 0.5rem;
    }

    .upload-hint {
        font-size: 0.875rem;
        color: #6c757d;
    }

    .close-btn {
        position: absolute;
        top: 1rem;
        right: 1rem;
        background: none;
        border: none;
        font-size: 1.5rem;
        color: #6c757d;
        cursor: pointer;
        padding: 0.25rem 0.5rem;
        line-height: 1;
    }

    .close-btn:hover {
        color: #343a40;
    }
  </style>