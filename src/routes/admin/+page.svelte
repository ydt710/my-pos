<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase, makeUserAdmin } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Product } from '$lib/types';
    import type { Order, OrderStatus, OrderFilters } from '$lib/types/orders';
    import { makeUserAdmin as userServiceMakeUserAdmin } from '$lib/services/userService';
    import { getAllOrders, updateOrderStatus, getTopBuyingUsers, getUsersWithMostDebt, getAllUserBalances, logPaymentToLedger } from '$lib/services/orderService';
    import { fade, slide } from 'svelte/transition';
    import OrderDetailsModal from '$lib/components/OrderDetailsModal.svelte';
    import { showSnackbar } from '$lib/stores/snackbarStore';
    import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  
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
      recentOrders: [] as any[],
      cashToCollect: 0,
      cashCollected: 0
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
      { id: 'edibles', name: 'Edibles' },
      { id: 'headshop', name: 'Headshop' }
    ];
  
    let statsInterval: ReturnType<typeof setInterval>;
  
    let showImageModal = false;
    let tempImageUrl = '';
    let activeImageTab = 'upload'; // 'upload' or 'url'
  
    let activeSection = 'stats'; // For highlighting active nav item
  
    let showConfirmModal = false;
    let orderIdToDelete: string | null = null;
  
    let showProductConfirmModal = false;
    let productIdToDelete: number | null = null;
  
    let cashIn = {
      today: 0,
      week: 0,
      month: 0,
      year: 0,
      all: 0
    };
    let debtIn = 0;
    let debtCreated = {
      today: 0,
      week: 0,
      month: 0,
      year: 0,
      all: 0
    };
  
    let topBuyers: { user_id: string; name?: string; email?: string; total: number }[] = [];
    let mostDebtUsers: { user_id: string; name?: string; email?: string; balance: number }[] = [];
  
    const FLOAT_USER_ID = '27cfee48-5b04-4ee1-885f-b3ef31417099';
  
    function scrollToSection(sectionId: string) {
        const element = document.getElementById(sectionId);
        if (element) {
            const navHeight = 60; // Height of the sticky nav
            const elementPosition = element.getBoundingClientRect().top;
            const offsetPosition = elementPosition + window.pageYOffset - navHeight;
            
            window.scrollTo({
                top: offsetPosition,
                behavior: "smooth"
            });
        }
    }

    // Update active section based on scroll position
    function updateActiveSection() {
        const sections = ['stats', 'products', 'orders'];
        const navHeight = 60;
        
        for (const section of sections) {
            const element = document.getElementById(section);
            if (element) {
                const rect = element.getBoundingClientRect();
                if (rect.top <= navHeight && rect.bottom > navHeight) {
                    activeSection = section;
                    break;
                }
            }
        }
    }
  
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
          fetchStats(),
          loadOrders(),
          fetchTopBuyersAndDebtors()
        ]).catch(console.error);
        
        // Set up auto-refresh
        statsInterval = setInterval(fetchStats, 30000);
        
        // Add scroll event listener
        window.addEventListener('scroll', updateActiveSection);
      });
      
      return () => {
        if (statsInterval) clearInterval(statsInterval);
        window.removeEventListener('scroll', updateActiveSection);
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
      loading = true;
      error = '';
      try {
        const { error: err } = await supabase.from('products').delete().eq('id', id);
        if (err) throw err;
        products = products.filter(p => p.id !== id);
        showSnackbar('Product deleted successfully.');
        await fetchProducts();
      } catch (err) {
        console.error('Error deleting product:', err);
        error = 'Failed to delete product. Please try again.';
        showSnackbar(error);
      } finally {
        loading = false;
      }
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

        // Filter to only non-deleted, completed orders for revenue and stats
        const validOrders = (ordersData || []).filter(order => !order.deleted_at && order.status === 'completed');
        // Calculate total orders and revenue
        stats.totalOrders = validOrders.length;
        stats.totalRevenue = validOrders.reduce((total, order) => {
          // Include guest orders (no user_id) as well
          return total + (order.total || 0);
        }, 0);
        // Calculate top products
        const productStats = new Map();
        validOrders.forEach(order => {
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
        // Get recent orders (can include all, or only completed if you prefer)
        stats.recentOrders = (ordersData || [])
          .filter(order => !order.deleted_at)
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

        // --- NEW: Cash to Collect (pending cash orders) ---
        const pendingCashOrders = (ordersData || []).filter(order =>
          !order.deleted_at &&
          order.status === 'pending' &&
          order.payment_method === 'cash'
        );
        stats.cashToCollect = pendingCashOrders.reduce((sum, order) => sum + (order.total || 0), 0);

        // --- NEW: Cash Collected (completed cash orders) ---
        const completedCashOrders = (ordersData || []).filter(order =>
          !order.deleted_at &&
          order.status === 'completed' &&
          order.payment_method === 'cash'
        );
        stats.cashCollected = completedCashOrders.reduce((sum, order) => sum + (order.total || 0), 0);

        // --- LEDGER-BASED CASH IN & DEBT CALCULATION ---
        const now = new Date();
        const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const startOfWeek = new Date(now);
        startOfWeek.setDate(now.getDate() - now.getDay());
        startOfWeek.setHours(0,0,0,0);
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const startOfYear = new Date(now.getFullYear(), 0, 1);

        // Helper to get ISO string for Supabase
        function iso(date: Date): string { return date.toISOString(); }

        // Fetch all payment (cash in) ledger entries
        const { data: ledgerPayments, error: ledgerPaymentsError } = await supabase
          .from('credit_ledger')
          .select('amount, created_at, user_id')
          .eq('type', 'payment');
        if (ledgerPaymentsError) throw ledgerPaymentsError;

        cashIn = { today: 0, week: 0, month: 0, year: 0, all: 0 };
        for (const entry of ledgerPayments) {
          const created = new Date(entry.created_at);
          if (created >= startOfToday) cashIn.today += entry.amount;
          if (created >= startOfWeek) cashIn.week += entry.amount;
          if (created >= startOfMonth) cashIn.month += entry.amount;
          if (created >= startOfYear) cashIn.year += entry.amount;
          cashIn.all += entry.amount;
        }

        // Fetch all debt (order) ledger entries
        const { data: ledgerDebts, error: ledgerDebtsError } = await supabase
          .from('credit_ledger')
          .select('amount, created_at, order_id, user_id, type');
        if (ledgerDebtsError) throw ledgerDebtsError;

        // Group ledger entries by order_id
        const orderLedgerMap = new Map();
        for (const entry of ledgerDebts) {
          if (!entry.order_id) continue;
          if (!orderLedgerMap.has(entry.order_id)) orderLedgerMap.set(entry.order_id, []);
          orderLedgerMap.get(entry.order_id).push(entry);
        }

        // Helper to sum outstanding debt for a set of orders
        function sumOutstandingDebt(orders: Order[], startDate: Date | undefined): number {
          let sum = 0;
          for (const order of orders) {
            if ((order as any).deleted_at || order.status !== 'completed') continue;
            if (!order.user_id) continue; // Only include registered users
            if (startDate && new Date(order.created_at) < startDate) continue;
            const ledgerEntries: any[] = orderLedgerMap.get(order.id) || [];
            const orderTotal = order.total || 0;
            const payments = ledgerEntries.filter((e: any) => e.type === 'payment' && e.amount > 0).reduce((s: number, e: any) => s + e.amount, 0);
            sum += Math.max(orderTotal - payments, 0); // Only count positive outstanding debt
          }
          return sum;
        }

        debtCreated = {
          today: sumOutstandingDebt(validOrders, startOfToday),
          week: sumOutstandingDebt(validOrders, startOfWeek),
          month: sumOutstandingDebt(validOrders, startOfMonth),
          year: sumOutstandingDebt(validOrders, startOfYear),
          all: sumOutstandingDebt(validOrders, undefined)
        };
        // Calculate total outstanding debt (sum of all negative user balances)
        const allUserBalances = await getAllUserBalances();
        debtIn = Object.values(allUserBalances)
          .filter((balance) => (balance as number) < 0)
          .reduce((sum, balance) => (sum as number) + Math.abs(balance as number), 0);

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
      // TODO: Replace with a proper confirmation modal
      showSnackbar('Delete all orders confirmation not implemented. Please add a modal.');
      return;
      // if (!confirm('WARNING: This will delete ALL orders and order items. This action cannot be undone. Are you sure?')) {
      //   return;
      // }

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
        // Find the order in the orders array
        const order = orders.find(o => o.id === orderId);
        // If marking as completed, payment method is cash, and no payment logged yet
        if (order && newStatus === 'completed' && order.payment_method === 'cash') {
          // Check if a payment already exists in the ledger for this order
          const { data: ledgerPayments } = await supabase
            .from('credit_ledger')
            .select('id')
            .eq('order_id', orderId)
            .eq('type', 'payment');
          if (!ledgerPayments || ledgerPayments.length === 0) {
            if (order.user_id) {
              await logPaymentToLedger(order.user_id, order.total, orderId, 'Cash payment on completion (admin)', 'cash');
            } else {
              // Guest order: log to float user
              await logPaymentToLedger(FLOAT_USER_ID, order.total, orderId, 'Guest cash payment on completion (admin)', 'cash');
            }
          }
        }
        await loadOrders(); // Refresh the list
        if (selectedOrder?.id === orderId) {
          selectedOrder.status = newStatus; // Update modal if open
        }
        // Refresh stats to update cashIn
        await fetchStats();
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
  
    async function deleteOrder(orderId: string) {
      loadingOrders = true;
      orderError = null;
      try {
        // Fetch the order to check if it's already deleted
        const { data: orderCheck, error: fetchCheckError } = await supabase
          .from('orders')
          .select('deleted_at')
          .eq('id', orderId)
          .single();
        if (fetchCheckError) throw fetchCheckError;
        if (orderCheck.deleted_at) {
          showSnackbar('Order has already been deleted.');
          return;
        }
        // Fetch the order and its items
        const { data: orderData, error: fetchError } = await supabase
          .from('orders')
          .select('id, order_items (product_id, quantity)')
          .eq('id', orderId)
          .single();
        if (fetchError) throw fetchError;
        // Reapply stock for each product in the order
        for (const item of orderData.order_items) {
          await supabase.rpc('increment_product_quantity', {
            product_id: item.product_id,
            amount: item.quantity
          });
        }
        // Soft delete the order and set status to 'cancelled', deleted_by, and deleted_by_role
        const { error: updateError } = await supabase
          .from('orders')
          .update({ 
            deleted_at: new Date().toISOString(), 
            status: 'cancelled', 
            deleted_by: user?.id, 
            deleted_by_role: 'admin' 
          })
          .eq('id', orderId);
        if (updateError) throw updateError;
        // After successful soft delete
        orders = orders.filter(o => o.id !== orderId);
        showSnackbar('Order deleted (soft delete) and stock reapplied.');
        // Optionally, refresh in the background
        loadOrders();
      } catch (err) {
        console.error('Error deleting order:', err);
        orderError = 'Failed to delete order. Please try again.';
        showSnackbar(orderError);
      } finally {
        loadingOrders = false;
      }
    }
  
    $: if (activeTab === 'orders') {
      loadOrders();
    }

    async function fetchTopBuyersAndDebtors() {
      const buyers = await getTopBuyingUsers(10);
      const debtors = await getUsersWithMostDebt(20); // fetch more to ensure enough negative balances
      topBuyers = buyers.map(u => ({ ...u, total: Number(u.total) }));
      // Only show users with negative balance (actual debt)
      mostDebtUsers = debtors
        .map(u => ({ ...u, balance: Number(u.balance) }))
        .filter(u => u.balance < 0)
        .slice(0, 10);
    }

    $: topBuyer = topBuyers && topBuyers.length > 0 ? topBuyers[0] : null;
    $: mostDebtUser = mostDebtUsers && mostDebtUsers.length > 0 ? mostDebtUsers[0] : null;
</script>
  
<div class="admin-container">
    <nav class="admin-nav">
        <div class="nav-content">
            <h1>Admin Dashboard</h1>
            <div class="nav-links">
                <button 
                    class:active={activeSection === 'stats'} 
                    on:click={() => scrollToSection('stats')}
                >
                    Statistics
                </button>
                <button 
                    class:active={activeSection === 'products'} 
                    on:click={() => scrollToSection('products')}
                >
                    Products
                </button>
                <button 
                    class:active={activeSection === 'orders'} 
                    on:click={() => scrollToSection('orders')}
                >
                    Orders
                </button>
            </div>
        </div>
    </nav>

    {#if error}
        <div class="alert error" transition:fade>{error}</div>
    {/if}

    {#if success}
        <div class="alert success" transition:fade>{success}</div>
    {/if}

    <!-- Statistics Section -->
    <section id="stats" class="stats-section">
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
            <div class="stat-card">
                <h3>Cash to Collect</h3>
                <p class="stat-value">R{stats.cashToCollect.toFixed(2)}</p>
            </div>
            <div class="stat-card">
                <h3>Cash Collected</h3>
                <p class="stat-value">R{stats.cashCollected.toFixed(2)}</p>
            </div>
            <div class="stat-card">
                <h3>Cash In</h3>
                <ul class="stat-list">
                  <li>Today: <strong>R{cashIn.today.toFixed(2)}</strong></li>
                  <li>This Week: <strong>R{cashIn.week.toFixed(2)}</strong></li>
                  <li>This Month: <strong>R{cashIn.month.toFixed(2)}</strong></li>
                  <li>This Year: <strong>R{cashIn.year.toFixed(2)}</strong></li>
                  <li>All Time: <strong>R{cashIn.all.toFixed(2)}</strong></li>
                </ul>
            </div>
            <div class="stat-card">
                <h3>Debt In</h3>
                <p class="stat-value">R{debtIn.toFixed(2)}</p>
            </div>
            <div class="stat-card">
                <h3>Debt Created</h3>
                <ul class="stat-list">
                  <li>Today: <strong>R{debtCreated.today.toFixed(2)}</strong></li>
                  <li>This Week: <strong>R{debtCreated.week.toFixed(2)}</strong></li>
                  <li>This Month: <strong>R{debtCreated.month.toFixed(2)}</strong></li>
                  <li>This Year: <strong>R{debtCreated.year.toFixed(2)}</strong></li>
                  <li>All Time: <strong>R{debtCreated.all.toFixed(2)}</strong></li>
                </ul>
            </div>
            <!-- Top Buyers as a list -->
            <div class="stat-card">
                <h3>Top Buyers</h3>
                <ul class="user-list">
                  {#each topBuyers.slice(0, 5) as user}
                    <li>
                      <span class="user-name">{user.name || user.email || user.user_id}</span>
                      <span class="user-amount">R{user.total.toFixed(2)}</span>
                    </li>
                  {/each}
                  {#if topBuyers.length === 0}
                    <li>No data</li>
                  {/if}
                </ul>
            </div>
            <!-- Most Debt Users as a list -->
            <div class="stat-card">
                <h3>Most Debt</h3>
                <ul class="user-list">
                  {#each mostDebtUsers.slice(0, 5) as user}
                    <li>
                      <span class="user-name">{user.name || user.email || user.user_id}</span>
                      <span class="user-amount" style="color: #dc3545;">R{Math.abs(user.balance).toFixed(2)}</span>
                    </li>
                  {/each}
                  {#if mostDebtUsers.length === 0}
                    <li>No data</li>
                  {/if}
                </ul>
            </div>
            <!-- Most Selling Product Card -->
            <div class="stat-card">
                <h3>Most Selling Products</h3>
                <ul class="user-list">
                  {#each stats.topProducts.slice(0, 5) as product}
                    <li>
                      <span class="user-name">{product.name}</span>
                      <span class="user-amount" style="color: #007bff;">{product.quantity}</span>
                    </li>
                  {/each}
                  {#if stats.topProducts.length === 0}
                    <li>No data</li>
                  {/if}
                </ul>
            </div>
        </div>

        <div class="stats-details">
            <!-- Remove the four stats-card tables here -->
        </div>
    </section>

    <!-- Product Management Section -->
    <section id="products" class="product-management">
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
            <div class="table-responsive desktop-only">
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
                            {#each products as p (p.id)}
                                <tr out:fade>
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
                                            on:click={() => { showProductConfirmModal = true; productIdToDelete = p.id; }}
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
            <!-- Mobile Card View -->
            <div class="mobile-cards">
                {#each products as p (p.id)}
                    <div class="admin-card">
                        <div class="admin-card-img-wrap">
                            <img src={p.image_url} alt={p.name} class="product-thumbnail" />
                        </div>
                        <div class="admin-card-body">
                            <div class="admin-card-title">{p.name}</div>
                            <div class="admin-card-row"><strong>Price:</strong> R{p.price}</div>
                            <div class="admin-card-row"><strong>Quantity:</strong> {p.quantity}</div>
                            <div class="admin-card-row"><strong>Category:</strong> {categories.find(c => c.id === p.category)?.name || p.category}</div>
                            <div class="admin-card-actions">
                                <button class="edit-btn" on:click={() => editProduct(p)}>Edit</button>
                                <button class="delete-btn" on:click={() => { showProductConfirmModal = true; productIdToDelete = p.id; }}>Delete</button>
                            </div>
                        </div>
                    </div>
                {/each}
            </div>
        </div>
    </section>

    <!-- Orders Section -->
    <section id="orders" class="orders-section" transition:fade>
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
                <div class="table-responsive desktop-only">
                    <div class="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th>Order #</th>
                                    <th>Date</th>
                                    <th>Customer</th>
                                    <th>Email</th>
                                    <th>Type</th>
                                    <th>Payment</th>
                                    <th>Total</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {#each orders as order (order.id)}
                                    <tr out:fade class:guest-order={order.guest_info}>
                                        <td>{order.order_number || order.id}</td>
                                        <td>{formatDate(order.created_at)}</td>
                                        <td>
                                            <div class="customer-info">
                                                <strong>{getCustomerInfo(order).name}</strong>
                                            </div>
                                        </td>
                                        <td>{getCustomerInfo(order).email}</td>
                                        <td>
                                            {#if order.guest_info}
                                                <span class="badge guest">Guest</span>
                                            {:else}
                                                <span class="badge registered">Registered</span>
                                            {/if}
                                        </td>
                                        <td>{order.payment_method || '-'}</td>
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
                                            <button
                                                class="delete-btn"
                                                on:click={() => { showConfirmModal = true; orderIdToDelete = order.id; }}
                                                style="margin-left: 0.5rem;"
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
                <!-- Mobile Card View -->
                <div class="mobile-cards">
                    {#each orders as order (order.id)}
                        <div class="admin-card">
                            <div class="admin-card-body">
                                <div class="admin-card-title">Order #{order.order_number || order.id}</div>
                                <div class="admin-card-row"><strong>Date:</strong> {formatDate(order.created_at)}</div>
                                <div class="admin-card-row"><strong>Customer:</strong> {getCustomerInfo(order).name}</div>
                                <div class="admin-card-row"><strong>Email:</strong> {getCustomerInfo(order).email}</div>
                                <div class="admin-card-row"><strong>Type:</strong> {order.guest_info ? 'Guest' : 'Registered'}</div>
                                <div class="admin-card-row"><strong>Payment:</strong> {order.payment_method || '-'}</div>
                                <div class="admin-card-row"><strong>Total:</strong> R{order.total}</div>
                                <div class="admin-card-row">
                                    <strong>Status:</strong>
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
                                </div>
                                <div class="admin-card-actions">
                                    <button class="view-details-btn" on:click={() => selectedOrder = order}>View Details</button>
                                    <button class="delete-btn" on:click={() => { showConfirmModal = true; orderIdToDelete = order.id; }}>Delete</button>
                                </div>
                            </div>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}
    </section>

    {#if selectedOrder}
        <OrderDetailsModal
            order={selectedOrder}
            onClose={() => selectedOrder = null}
            onStatusUpdate={handleStatusUpdate}
        />
    {/if}

    {#if showImageModal}
        <div class="modal-backdrop"
             role="button"
             tabindex="0"
             on:click={() => showImageModal = false}
             on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && (showImageModal = false)}>
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

    {#if showConfirmModal}
        <ConfirmModal
            message="Are you sure you want to delete this order?"
            onConfirm={() => { if (orderIdToDelete) deleteOrder(orderIdToDelete); showConfirmModal = false; orderIdToDelete = null; }}
            onCancel={() => { showConfirmModal = false; orderIdToDelete = null; }}
        />
    {/if}

    {#if showProductConfirmModal}
        <ConfirmModal
            message="Are you sure you want to delete this product?"
            onConfirm={() => { if (productIdToDelete !== null) deleteProduct(productIdToDelete); showProductConfirmModal = false; productIdToDelete = null; }}
            onCancel={() => { showProductConfirmModal = false; productIdToDelete = null; }}
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

    .admin-nav {
        position: sticky;
        top: 0;
        background: white;
        z-index: 100;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
       
        padding: 1rem 2rem;
    }

    .nav-content {
        max-width: 1400px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .nav-content h1 {
        margin: 0;
        font-size: 1.5rem;
        color: #333;
    }

    .nav-links {
        display: flex;
        gap: 1rem;
    }

    .nav-links button {
        padding: 0.5rem 1rem;
        border: none;
        background: none;
        color: #6c757d;
        font-size: 1rem;
        cursor: pointer;
        transition: all 0.2s;
        border-bottom: 2px solid transparent;
    }

    .nav-links button:hover {
        color: #007bff;
    }

    .nav-links button.active {
        color: #007bff;
        border-bottom-color: #007bff;
    }

    section {
        scroll-margin-top: 80px; /* Accounts for sticky nav */
        padding: 2rem 0;
    }

    section:not(:last-child) {
        border-bottom: 1px solid #dee2e6;
        margin-bottom: 2rem;
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
        
        max-width: 300px;
        margin: 0 auto;
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
        position: relative;
    }

    .preview-image {
        width: 100%;
        height: 100%;
        object-fit: contain;
        object-position: center;
        background: #fff;
        padding: 0.5rem;
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

    /* Add aspect ratio container for product thumbnails in table */
    td .product-thumbnail {
        width: 60px;
        height: 60px;
        object-fit: cover;
        object-position: center;
        border-radius: 4px;
        background: #fff;
        padding: 2px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }

    /* Style for the image preview modal */
    .modal-image-preview {
        max-width: 90%;
        max-height: 80vh;
        object-fit: contain;
        border-radius: 8px;
        background: #fff;
        padding: 1rem;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
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
            padding: 0.5rem;
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
            width: 100%;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
        }

        .table-container {
            min-width: 600px;
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
            gap: 0.5rem;
        }

        input, select, textarea {
            width: 100%;
            max-width: none;
            font-size: 1rem;
        }

        .filters {
            grid-template-columns: 1fr;
            gap: 0.5rem;
        }

        .action-buttons {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }

        .action-buttons button {
            width: 100%;
            font-size: 1rem;
        }

        .section-header {
            flex-direction: column;
            gap: 0.5rem;
            align-items: stretch;
            text-align: center;
        }

        .section-header button {
            width: 100%;
            font-size: 1rem;
        }

        .nav-content {
            flex-direction: column;
            gap: 1rem;
            text-align: center;
        }

        .nav-links {
            width: 100%;
            justify-content: center;
            flex-wrap: wrap;
        }

        .nav-links button {
            flex: 1;
            min-width: 120px;
        }

        section {
            scroll-margin-top: 120px; /* Accounts for larger nav on mobile */
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

    .stat-list {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    .stat-list li {
        font-size: 1rem;
        margin-bottom: 0.25rem;
    }

    .badge {
        display: inline-block;
        padding: 0.25em 0.75em;
        border-radius: 12px;
        font-size: 0.85em;
        font-weight: 600;
        color: #fff;
    }
    .badge.guest {
        background: #6c757d;
    }
    .badge.registered {
        background: #007bff;
    }
    tr.guest-order {
        background: #f8f9fa;
    }

    .user-list {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    .user-list li {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.25rem 0;
        border-bottom: 1px solid #f0f0f0;
        font-size: 1rem;
    }
    .user-list li:last-child {
        border-bottom: none;
    }
    .user-name {
        font-weight: 500;
        color: #333;
        max-width: 60%;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }
    .user-amount {
        font-weight: 600;
        color: #007bff;
        min-width: 80px;
        text-align: right;
    }

    .desktop-only { display: block; }
    .mobile-cards { display: none; }
    @media (max-width: 768px) {
        .desktop-only { display: none !important; }
        .mobile-cards { display: block; }
        .mobile-cards .admin-card {
            background: #fff;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            margin-bottom: 1rem;
            padding: 1rem;
            display: flex;
            gap: 1rem;
            flex-direction: row;
            align-items: flex-start;
        }
        .admin-card-img-wrap {
            flex-shrink: 0;
            width: 60px;
            height: 60px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #f8f9fa;
            border-radius: 8px;
            overflow: hidden;
        }
        .admin-card-img-wrap img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            border-radius: 8px;
        }
        .admin-card-body {
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }
        .admin-card-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin-bottom: 0.25rem;
        }
        .admin-card-row {
            font-size: 0.98rem;
            margin-bottom: 0.15rem;
        }
        .admin-card-actions {
            display: flex;
            gap: 0.5rem;
            margin-top: 0.5rem;
        }
        .admin-card-actions button {
            flex: 1;
            font-size: 1rem;
            padding: 0.5rem 0.75rem;
        }
    }
</style>