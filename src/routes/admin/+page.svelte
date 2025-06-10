<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase, makeUserAdmin } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Product } from '$lib/types/index';
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
    let filteredProducts: Product[] = [];
    let loading = true;
    let error = '';
    let success = '';
    let editing: Product | null = null;
    let newProduct: Partial<Product> = { 
      name: '', 
      description: '',
      price: 0, 
      image_url: '', 
      category: 'flower', // Default category
      thc_max: 0,
      cbd_max: 0,
      indica: 0
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
    let productIdToDelete: string | null = null;
  
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
  
    const FLOAT_USER_ID = 'ab54f66c-fa1c-40d2-ad2a-d9d5c1603e0f';
  
    // Add product filters
    let productFilters = {
      search: '',
      category: '',
      minPrice: '',
      maxPrice: '',
      sortBy: 'name',
      sortOrder: 'asc'
    };
  
    // --- Custom Prices State ---
    let showCustomPrices = false;
    let customPrices: { id: string, user_id: string, product_id: string, custom_price: number, email?: string, display_name?: string }[] = [];
    let customPriceUserSearch = '';
    let customPriceUserResults: { id: string, email: string, display_name: string }[] = [];
    let newCustomPrice = '';
    let selectedCustomPriceUser: { id: string, email: string, display_name: string } | null = null;
    let customPriceError = '';
    let customPriceUserLoading = false;
  
    let showDescriptionModal = false;
    let tempDescription = '';
  
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
        // Query profiles for is_admin
        supabase
          .from('profiles')
          .select('is_admin')
          .eq('auth_user_id', user.id)
          .maybeSingle()
          .then(({ data: profile }) => {
            isAdmin = !!profile?.is_admin;
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
      else {
        products = data;
        applyProductFilters();
      }
    }
  
    function applyProductFilters() {
      filteredProducts = products.filter(product => {
        // Search filter
        if (productFilters.search && !product.name.toLowerCase().includes(productFilters.search.toLowerCase())) {
          return false;
        }
        
        // Category filter
        if (productFilters.category && product.category !== productFilters.category) {
          return false;
        }
        
        // Price range filter
        if (productFilters.minPrice && product.price < Number(productFilters.minPrice)) {
          return false;
        }
        if (productFilters.maxPrice && product.price > Number(productFilters.maxPrice)) {
          return false;
        }
        
        return true;
      });

      // Apply sorting
      filteredProducts.sort((a, b) => {
        let comparison = 0;
        switch (productFilters.sortBy) {
          case 'name':
            comparison = a.name.localeCompare(b.name);
            break;
          case 'price':
            comparison = a.price - b.price;
            break;
          case 'category':
            comparison = a.category.localeCompare(b.category);
            break;
          default:
            comparison = 0;
        }
        return productFilters.sortOrder === 'asc' ? comparison : -comparison;
      });
    }
  
    $: if (products.length > 0) {
      applyProductFilters();
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
                const { data, error: err } = await supabase
                    .from('products')
                    .insert([{ ...newProduct, image_url: imageUrl }])
                    .select()
                    .single();
                
                if (err) {
                  error = err.message;
                } else if (data) {
                  // Insert initial stock level for the new product at the 'shop' location
                  const newProductId = data.id; // Assuming the inserted data includes the new product's ID
                  const shopLocationId = 'e0ff9565-e490-45e9-991f-298918e4514a'; // Replace with dynamic lookup if needed
                  const { error: stockError } = await supabase
                    .from('stock_levels')
                    .insert([{ product_id: newProductId, location_id: shopLocationId, quantity: 0 }]);
                  
                  if (stockError) {
                    console.error('Error inserting initial stock level:', stockError);
                    // Optionally set an error message for the user, but the product was created
                  }

                newProduct = { 
                    name: '', 
                    description: '',
                    price: 0, 
                    image_url: '', 
                    category: 'flower',
                    thc_max: 0,
                    cbd_max: 0,
                    indica: 0
                };
                }
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
  
    async function deleteProduct(id: string) {
      loading = true;
      error = '';
      try {
        const { error: err } = await supabase.from('products').delete().eq('id', id);
        if (err) throw err;
        products = products.filter(p => String(p.id) !== String(id));
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

        // --- NEW: Cash Collected (from ledger, actual cash received today) ---
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

        // --- NEW: Cash Collected (from ledger, actual cash received today) ---
        const todayISO = startOfToday.toISOString();
        stats.cashCollected = ledgerPayments
          .filter(entry => new Date(entry.created_at) >= startOfToday)
          .reduce((sum, entry) => sum + entry.amount, 0);

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
        // Use display_name, phone_number, address from profiles if available
        const name = 'display_name' in order.user && order.user.display_name
          ? order.user.display_name
          : order.user.email?.split('@')[0] || 'N/A';
        const phone = 'phone_number' in order.user && order.user.phone_number
          ? order.user.phone_number
          : 'N/A';
        const address = 'address' in order.user && order.user.address
          ? order.user.address
          : 'N/A';
        return {
          name,
          email: order.user.email || 'N/A',
          phone,
          address
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
        // Fetch all order items for this order
        const { data: orderItems, error: itemsError } = await supabase
          .from('order_items')
          .select('product_id, quantity')
          .eq('order_id', orderId);
        if (itemsError) throw itemsError;
        // Reapply stock for each product in the order
        for (const item of orderItems) {
          // Increment product quantity
          await supabase.rpc('increment_product_quantity', {
            product_id: item.product_id,
            amount: item.quantity
          });
        }
        // Delete all order_items for this order
        await supabase.from('order_items').delete().eq('order_id', orderId);
        // Delete all credit_ledger entries for this order
        await supabase.from('credit_ledger').delete().eq('order_id', orderId);
        // Delete the order itself
        await supabase.from('orders').delete().eq('id', orderId);
        // Remove from UI
        orders = orders.filter(o => o.id !== orderId);
        showSnackbar('Order and all related data deleted. Stock reapplied.');
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

    async function fetchCustomPricesForProduct(productId: string) {
      if (!productId) { customPrices = []; return; }
      const { data, error } = await supabase
        .from('user_product_prices')
        .select('id, user_id, product_id, custom_price, profiles: user_id (email, display_name)')
        .eq('product_id', productId);
      if (error) { customPrices = []; return; }
      customPrices = (data || []).map(row => {
        let profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
        return {
          id: row.id,
          user_id: row.user_id,
          product_id: row.product_id,
          custom_price: row.custom_price,
          email: profile?.email,
          display_name: profile?.display_name
        };
      });
    }

    async function searchCustomPriceUsers() {
      if (customPriceUserSearch.length < 2) {
        customPriceUserResults = [];
        return;
      }
      customPriceUserLoading = true;
      const { data, error } = await supabase
        .from('profiles')
        .select('id, email, display_name')
        .or(`display_name.ilike.%${customPriceUserSearch}%,email.ilike.%${customPriceUserSearch}%`)
        .limit(10);
      customPriceUserResults = data || [];
      customPriceUserLoading = false;
    }

    function selectCustomPriceUser(user: { id: string, email: string, display_name: string }) {
      selectedCustomPriceUser = user;
      customPriceUserResults = [];
      customPriceUserSearch = user.display_name || user.email;
    }

    async function addCustomPrice() {
      customPriceError = '';
      if (!selectedCustomPriceUser || !editing || !newCustomPrice) {
        customPriceError = 'Select a user and enter a price.';
        return;
      }
      const { error } = await supabase
        .from('user_product_prices')
        .upsert([
          {
            user_id: selectedCustomPriceUser.id,
            product_id: String(editing.id),
            custom_price: Number(newCustomPrice)
          }
        ], { onConflict: 'user_id,product_id' });
      if (error) {
        customPriceError = error.message;
        return;
      }
      await fetchCustomPricesForProduct(String(editing.id));
      selectedCustomPriceUser = null;
      customPriceUserSearch = '';
      newCustomPrice = '';
    }

    async function removeCustomPrice(id: string) {
      await supabase.from('user_product_prices').delete().eq('id', id);
      if (editing) await fetchCustomPricesForProduct(String(editing.id));
    }

    $: if (editing && showCustomPrices) {
      fetchCustomPricesForProduct(String(editing.id));
    }
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
                <div class="mobile-cards mobile-only">
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
        <div 
            class="modal-backdrop"
            role="dialog"
            aria-modal="true"
            aria-label="Image upload modal"
            tabindex="0"
            on:click={() => showImageModal = false}
            on:keydown={(e) => e.key === 'Escape' && (showImageModal = false)}>
            <div 
                class="modal-content" 
                role="button"
                on:click|stopPropagation
                on:keydown={(e) => e.key === 'Escape' && (showImageModal = false)}
                tabindex="0">
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
        <!-- Product Management Section -->
    <section id="products" class="product-management">
        <div class="section-header">
            <h2>Product Management</h2>
        </div>

  

        <!-- Product Filters -->
        <div class="filters-card">
            <div class="filters-grid">
                <div class="filter-group">
                    <label for="search">Search</label>
                    <input 
                        id="search"
                        type="text"
                        placeholder="Search products..."
                        bind:value={productFilters.search}
                        on:input={applyProductFilters}
                    />
                </div>
                <div class="filter-group">
                    <label for="category">Category</label>
                    <select 
                        id="category"
                        bind:value={productFilters.category}
                        on:change={applyProductFilters}
                    >
                        <option value="">All Categories</option>
                        {#each categories as category}
                            <option value={category.id}>{category.name}</option>
                        {/each}
                    </select>
                </div>
                <div class="filter-group">
                    <label for="minPrice">Min Price</label>
                    <input 
                        id="minPrice"
                        type="number"
                        min="0"
                        step="0.01"
                        placeholder="Min price"
                        bind:value={productFilters.minPrice}
                        on:input={applyProductFilters}
                    />
                </div>
                <div class="filter-group">
                    <label for="maxPrice">Max Price</label>
                    <input 
                        id="maxPrice"
                        type="number"
                        min="0"
                        step="0.01"
                        placeholder="Max price"
                        bind:value={productFilters.maxPrice}
                        on:input={applyProductFilters}
                    />
                </div>
                <div class="filter-group">
                    <label for="sortBy">Sort By</label>
                    <select 
                        id="sortBy"
                        bind:value={productFilters.sortBy}
                        on:change={applyProductFilters}
                    >
                        <option value="name">Name</option>
                        <option value="price">Price</option>
                        <option value="category">Category</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="sortOrder">Order</label>
                    <select 
                        id="sortOrder"
                        bind:value={productFilters.sortOrder}
                        on:change={applyProductFilters}
                    >
                        <option value="asc">Ascending</option>
                        <option value="desc">Descending</option>
                    </select>
                </div>
            </div>
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
                    <div class="form-group">
                        <label for="thc_max">THC Max (mg/g)</label>
                        {#if editing}
                            <input 
                                id="thc_max"
                                type="number"
                                min="0"
                                step="0.01"
                                bind:value={editing.thc_max}
                                placeholder="THC max (mg/g)"
                                required
                            />
                        {:else}
                            <input 
                                id="thc_max"
                                type="number"
                                min="0"
                                step="0.01"
                                bind:value={newProduct.thc_max}
                                placeholder="THC max (mg/g)"
                                required
                            />
                        {/if}
                    </div>
                    <div class="form-group">
                        <label for="cbd_max">CBD Max (mg/g)</label>
                        {#if editing}
                            <input 
                                id="cbd_max"
                                type="number"
                                min="0"
                                step="0.01"
                                bind:value={editing.cbd_max}
                                placeholder="CBD max (mg/g)"
                                required
                            />
                        {:else}
                            <input 
                                id="cbd_max"
                                type="number"
                                min="0"
                                step="0.01"
                                bind:value={newProduct.cbd_max}
                                placeholder="CBD max (mg/g)"
                                required
                            />
                        {/if}
                    </div>
                    <div class="form-group">
                        <label for="indica">Indica (%)</label>
                        {#if editing}
                            <input 
                                id="indica"
                                type="number"
                                min="0"
                                max="100"
                                step="1"
                                bind:value={editing.indica}
                                placeholder="Indica % (0-100)"
                                required
                            />
                        {:else}
                            <input 
                                id="indica"
                                type="number"
                                min="0"
                                max="100"
                                step="1"
                                bind:value={newProduct.indica}
                                placeholder="Indica % (0-100)"
                                required
                            />
                        {/if}
                    </div>
                    <div class="form-group">
                        <label for="description">Description</label>
                        <div style="display:flex;align-items:center;gap:0.5rem;">
                            {#if editing}
                                <textarea id="description" bind:value={editing!.description} rows="2" readonly style="flex:1;resize:none;background:#f8f9fa;cursor:pointer;" on:click={() => { tempDescription = editing!.description || ''; showDescriptionModal = true; }} placeholder="Product description..."></textarea>
                            {:else}
                                <textarea id="description" bind:value={newProduct.description} rows="2" readonly style="flex:1;resize:none;background:#f8f9fa;cursor:pointer;" on:click={() => { tempDescription = newProduct.description || ''; showDescriptionModal = true; }} placeholder="Product description..."></textarea>
                            {/if}
                            <button type="button" class="secondary-btn" on:click={() => { tempDescription = editing ? (editing.description || '') : (newProduct.description || ''); showDescriptionModal = true; }}>Edit</button>
                        </div>
                    </div>
                </div>
                <div class="form-actions">
                    {#if editing !== null}
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
                        <button type="button" class="secondary-btn" on:click={() => showCustomPrices = true} style="margin-left:1rem;">
                            Custom Prices
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
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Image</th>
                            <th>Name</th>
                            <th>Category</th>
                            <th>Price</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {#each filteredProducts as product (product.id)}
                            <tr>
                                <td>
                                    <img 
                                        src={product.image_url} 
                                        alt={product.name}
                                        class="product-thumbnail"
                                    />
                                </td>
                                <td>{product.name}</td>
                                <td>{categories.find(c => String(c.id) === String(product.category))?.name || product.category}</td>
                                <td>R{product.price}</td>
                                <td class="action-buttons">
                                    <button 
                                        class="edit-btn"
                                        on:click={() => editProduct(product)}
                                    >
                                        Edit
                                    </button>
                                    <button 
                                        class="delete-btn"
                                        on:click={() => { showProductConfirmModal = true; productIdToDelete = String(product.id); }}
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

    {#if editing && showCustomPrices}
      <div class="modal-backdrop" style="z-index:2000;" on:click={() => showCustomPrices = false}></div>
      <div class="modal custom-prices-modal" style="z-index:2001;" role="dialog" aria-modal="true">
        <button class="close-btn" on:click={() => showCustomPrices = false} aria-label="Close custom prices modal">×</button>
        <h3>Custom Prices for this Product</h3>
        <div style="margin-bottom:1rem;">
          <input type="text" placeholder="Search user by name or email..." bind:value={customPriceUserSearch} on:input={searchCustomPriceUsers} style="min-width:200px; width:100%;" />
          {#if customPriceUserLoading}
            <span>Searching...</span>
          {/if}
          {#if customPriceUserResults.length > 0}
            <ul style="background:#fff;border:1px solid #eee;max-height:120px;overflow-y:auto;margin:0;padding:0;list-style:none;">
              {#each customPriceUserResults as user}
                <li style="padding:0.5rem;cursor:pointer;" on:click={() => selectCustomPriceUser(user)}>{user.display_name || user.email} <span style="color:#888;font-size:0.9em;">({user.email})</span></li>
              {/each}
            </ul>
          {/if}
        </div>
        {#if selectedCustomPriceUser}
          <div style="margin-bottom:0.5rem;">
            Selected: <strong>{selectedCustomPriceUser.display_name || selectedCustomPriceUser.email}</strong>
          </div>
        {/if}
        <div style="display:flex;align-items:center;gap:0.5rem;margin-bottom:1rem;">
          <input type="number" min="0" step="0.01" placeholder="Custom price" bind:value={newCustomPrice} style="width:120px;" />
          <button type="button" class="primary-btn" on:click={addCustomPrice}>Add/Update</button>
        </div>
        {#if customPriceError}
          <div style="color:#dc3545;margin-bottom:0.5rem;">{customPriceError}</div>
        {/if}
        <table style="width:100%;margin-top:1rem;">
          <thead>
            <tr><th>User</th><th>Email</th><th>Custom Price</th><th>Action</th></tr>
          </thead>
          <tbody>
            {#each customPrices as cp}
              <tr>
                <td>{cp.display_name || '-'}</td>
                <td>{cp.email || '-'}</td>
                <td>R{cp.custom_price}</td>
                <td><button type="button" class="delete-btn" on:click={() => removeCustomPrice(cp.id)}>Remove</button></td>
              </tr>
            {/each}
            {#if customPrices.length === 0}
              <tr><td colspan="4" style="text-align:center;color:#888;">No custom prices set for this product.</td></tr>
            {/if}
          </tbody>
        </table>
      </div>
    {/if}

    {#if showDescriptionModal}
        <div class="modal-backdrop" style="z-index:2100;" on:click={() => showDescriptionModal = false}></div>
        <div class="modal" style="z-index:2101;min-width:350px;max-width:95vw;top:50%;left:50%;transform:translate(-50%,-50%);position:fixed;background:#fff;padding:2rem;border-radius:12px;box-shadow:0 2px 16px rgba(0,0,0,0.2);" role="dialog" aria-modal="true">
            <button class="close-btn" on:click={() => showDescriptionModal = false} aria-label="Close description modal" style="position:absolute;top:1rem;right:1rem;font-size:1.5rem;background:none;border:none;cursor:pointer;">×</button>
            <h3>Edit Description</h3>
            <textarea bind:value={tempDescription} rows="8" style="width:100%;margin-bottom:1rem;"></textarea>
            <div style="display:flex;justify-content:flex-end;gap:1rem;">
                <button type="button" class="primary-btn" on:click={() => {
                    if (editing) editing.description = tempDescription;
                    else newProduct.description = tempDescription;
                    showDescriptionModal = false;
                }}>Save</button>
                <button type="button" class="secondary-btn" on:click={() => showDescriptionModal = false}>Cancel</button>
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
        font-size: 0.9rem;
        color: #666;
        font-weight: 500;
    }

    .filter-group input,
    .filter-group select {
        padding: 0.5rem;
        border: 1px solid #ddd;
        border-radius: 4px;
        font-size: 0.9rem;
    }

    .filter-group input:focus,
    .filter-group select:focus {
        outline: none;
        border-color: #007bff;
        box-shadow: 0 0 0 2px rgba(0,123,255,0.25);
    }

    @media (max-width: 800px) {
        .filters-grid {
            grid-template-columns: 1fr;
        }
    }

    .mobile-only {
        display: none;
    }
    @media (max-width: 900px) {
        .mobile-only {
            display: block;
        }
        .desktop-only {
            display: none;
        }
    }

    .image-input-container {
        display: flex;
        align-items: center;
        gap: 1rem;
    }

    .image-preview {
        display: flex;
        align-items: center;
    }

    .preview-image {
        width: 60px;
        height: 60px;
        object-fit: cover;
        border-radius: 6px;
        border: 1px solid #eee;
    }

    .image-btn {
        padding: 0.5rem 1.2rem;
        border: 1px solid #007bff;
        background: #f8f9fa;
        color: #007bff;
        border-radius: 6px;
        font-size: 1rem;
        cursor: pointer;
        transition: background 0.2s, color 0.2s;
        margin-left: 0.5rem;
        white-space: nowrap;
    }

    .image-btn:hover {
        background: #007bff;
        color: #fff;
    }

    .modal-backdrop {
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0,0,0,0.4);
        z-index: 2000;
    }

    .modal.custom-prices-modal {
        position: fixed;
        top: 50%; left: 50%;
        transform: translate(-50%, -50%);
        background: #fff;
        padding: 2rem;
        border-radius: 12px;
        z-index: 2001;
        min-width: 350px;
        max-width: 95vw;
        box-shadow: 0 2px 16px rgba(0,0,0,0.2);
        max-height: 90vh;
        overflow-y: auto;
    }

    .modal.custom-prices-modal .close-btn {
        position: absolute;
        top: 1rem;
        right: 1rem;
        background: none;
        border: none;
        font-size: 1.5rem;
        cursor: pointer;
        color: #666;
        z-index: 2002;
        padding: 0.5rem;
        border-radius: 50%;
        transition: background-color 0.2s ease;
    }

    .modal.custom-prices-modal .close-btn:hover,
    .modal.custom-prices-modal .close-btn:focus {
        background-color: rgba(0, 0, 0, 0.1);
        outline: 2px solid #2196f3;
        outline-offset: 2px;
    }
</style>