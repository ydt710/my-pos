<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase, makeUserAdmin } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Product } from '$lib/types/index';
    import type { Order, OrderStatus, OrderFilters } from '$lib/types/orders';
    import { makeUserAdmin as userServiceMakeUserAdmin } from '$lib/services/userService';
    import { getAllOrders, updateOrderStatus, getTopBuyingUsers, getUsersWithMostDebt, getAllUserBalances, reapplyOrderStock } from '$lib/services/orderService';
    import { fade, slide } from 'svelte/transition';
    import OrderDetailsModal from '$lib/components/OrderDetailsModal.svelte';
    import { showSnackbar } from '$lib/stores/snackbarStore';
    import ConfirmModal from '$lib/components/ConfirmModal.svelte';
    import ProductEditModal from '$lib/components/ProductEditModal.svelte';
    import { getShopStockLevels } from '$lib/services/stockService';
    import Chart from 'chart.js/auto';
    import type { Chart as ChartType } from 'chart.js';
  
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
    let editing: Partial<Product> | null = null;
    let newProduct: Partial<Product> = { 
      name: '', 
      description: '',
      price: 0, 
      image_url: '', 
      category: 'flower', // Default category
      thc_max: 0,
      cbd_max: 0,
      indica: 0,
      is_new: false,
      is_special: false
    };
    let imageFile: File | null = null;
    let uploadProgress = 0;
    let isUploading = false;
    let user: any = null;
    let isAdmin = false;
    let isPosUser = false;
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
  
    // Add state for modal
    let showEditModal = false;
    let isAddMode = false;
  
    let stockLevels: { [productId: string]: number } = {};
  
    let showCancelConfirm = false;
    let orderIdToCancel: string | null = null;
  
    // State for revenue modal and chart
    let showRevenueModal = false;
    let revenueChart;
    let revenueChartInstance: ChartType | null = null;
    let revenueFilter = 'year'; // 'today' | 'week' | 'month' | 'year'
    let revenueChartData = [];
    let revenueChartLabels = [];
  
    let allOrders: Order[] = [];
  
    let showDebtCreatedModal = false;
    let debtCreatedChartInstance: ChartType | null = null;
    let debtCreatedFilter: 'today' | 'week' | 'month' | 'year' = 'year';
    let debtCreatedChartData: number[] = [];
    let debtCreatedChartLabels: string[] = [];
    let debtCreatedData: { created_at: string; debt: number }[] = [];
  
    function openEditModal(product: Product) {
      editing = { ...product };
      showEditModal = true;
      isAddMode = false;
    }
    function closeEditModal() {
      editing = null;
      showEditModal = false;
    }
  
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
      // Check if user is admin or POS
      supabase.auth.getUser().then(({ data }) => {
        user = data.user;
        // Query profiles for is_admin and role
        supabase
          .from('profiles')
          .select('is_admin, role')
          .eq('auth_user_id', user.id)
          .maybeSingle()
          .then(({ data: profile }) => {
            isAdmin = !!profile?.is_admin;
            isPosUser = profile?.role === 'pos';
            if (!isAdmin && !isPosUser) goto('/');
            // Initial load
            Promise.all([
              fetchProducts(),
              fetchStats(),
              loadOrders(),
              fetchTopBuyersAndDebtors(),
              fetchAndRenderDebtCreatedChart() // <-- Add this line
            ]).catch(console.error);
            // Add scroll event listener
            window.addEventListener('scroll', updateActiveSection);
          });
      });
      return () => {
        window.removeEventListener('scroll', updateActiveSection);
      };
    });
  
    async function fetchProducts() {
      loading = true;
      const { data, error: err } = await supabase.from('products').select('*');
      loading = false;
      if (err) error = err.message;
      else {
        products = (data ?? []).map(p => ({ ...p, id: String(p.id) })) as Product[];
        stockLevels = await getShopStockLevels(products.map(p => p.id));
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
            let imageUrl = editing ? editing.image_url : '';
            
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
            
            if (editing && editing.id) {
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
                    .insert([{ ...editing, image_url: imageUrl }])
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
                    indica: 0,
                    is_new: false,
                    is_special: false
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
  
   
  
    async function fetchStats() {
      try {
        // First, fetch orders with order items and products
        const { data: ordersData, error: ordersError } = await supabase
          .from('orders')
          .select(`
            *,
            order_items (
              *,
              products:product_id (
                name,
                image_url
              )
            ),
            profiles:user_id (
              email,
              display_name,
              phone_number,
              address
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

        // Fetch all payment (cash in) ledger entries (CASH ONLY)
        const { data: ledgerPayments, error: ledgerPaymentsError } = await supabase
          .from('transactions')
          .select('amount, created_at, user_id, method')
          .eq('type', 'payment')
          .eq('method', 'cash');
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

        // Fetch all settlement (debt payoff) ledger entries (CASH ONLY)
        const { data: ledgerSettlements, error: ledgerSettlementsError } = await supabase
          .from('transactions')
          .select('amount, created_at, user_id, method, order_id')
          .eq('type', 'settlement')
          .eq('method', 'cash');
        if (ledgerSettlementsError) throw ledgerSettlementsError;

        // Fetch all orders to check which were created with debt
        const { data: allOrdersForDebt } = await supabase
          .from('orders')
          .select('id, debt');
        const debtOrderIds = new Set((allOrdersForDebt || []).filter(order => order.debt > 0).map(order => order.id));

        // Calculate Debt In (sum of all cash settlements for orders that were originally created with debt)
        debtIn = (ledgerSettlements || [])
          .filter(entry => debtOrderIds.has(entry.order_id))
          .reduce((sum, entry) => sum + entry.amount, 0);

        // --- NEW: Cash Collected (from ledger, actual cash received today) ---
        const todayISO = startOfToday.toISOString();
        stats.cashCollected = ledgerPayments
          .filter(entry => new Date(entry.created_at) >= startOfToday)
          .reduce((sum, entry) => sum + entry.amount, 0);

        allOrders = ordersData || [];

        // --- NEW: Debt In (all payments that reduce debt, any method) ---
        const { data: debtPayments, error: debtPaymentsError } = await supabase
          .from('transactions')
          .select('amount, created_at, user_id, method, order_id')
          .gt('amount', 0); // Only positive amounts (payments in)
        if (debtPaymentsError) throw debtPaymentsError;

        debtIn = (debtPayments || []).reduce((sum, entry) => sum + entry.amount, 0);

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
      // If cancelling, show confirm dialog
      if (newStatus === 'cancelled') {
        showCancelConfirm = true;
        orderIdToCancel = orderId;
        return;
      }
      const { success, error } = await updateOrderStatus(orderId, newStatus);
      if (success) {
        // Find the order in the orders array
        const order = orders.find(o => o.id === orderId);
        // If marking as completed, payment method is cash, and no payment logged yet
        if (order && newStatus === 'completed' && order.payment_method === 'cash') {
          // Check if a payment already exists in the ledger for this order
          const { data: ledgerPayments } = await supabase
            .from('transactions')
            .select('id')
            .eq('order_id', orderId)
            .eq('type', 'payment');
          if (!ledgerPayments || ledgerPayments.length === 0) {
            if (order.user_id) {
              // await logPaymentToLedger(order.user_id, order.total, orderId, 'Cash payment on completion (admin)', 'cash');
            } else {
              // Guest order: log to float user
              // await logPaymentToLedger(FLOAT_USER_ID, order.total, orderId, 'Guest cash payment on completion (admin)', 'cash');
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
  
    async function confirmCancelOrder() {
      if (!orderIdToCancel) return;
      // Reapply stock first
      const { success: stockSuccess, error: stockError } = await reapplyOrderStock(orderIdToCancel);
      if (!stockSuccess) {
        orderError = stockError || 'Failed to reapply stock.';
        showCancelConfirm = false;
        orderIdToCancel = null;
        return;
      }
      // Now update status
      const { success, error } = await updateOrderStatus(orderIdToCancel, 'cancelled');
      if (success) {
        await loadOrders();
        if (selectedOrder?.id === orderIdToCancel) {
          selectedOrder.status = 'cancelled';
        }
        await fetchStats();
      } else {
        orderError = error;
      }
      showCancelConfirm = false;
      orderIdToCancel = null;
    }

    function cancelCancelOrder() {
      showCancelConfirm = false;
      orderIdToCancel = null;
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

    // Helper to filter and group revenue data
    function getRevenueDataByFilter(orders: Order[], filter: string): { labels: string[], data: number[] } {
      const now = new Date();
      let start: Date;
      let format: (d: Date) => string;
      if (filter === 'today') {
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        format = (d: Date) => d.getHours() + ':00';
      } else if (filter === 'week') {
        start = new Date(now);
        start.setDate(now.getDate() - now.getDay());
        start.setHours(0,0,0,0);
        format = (d: Date) => d.toLocaleDateString();
      } else if (filter === 'month') {
        start = new Date(now.getFullYear(), now.getMonth(), 1);
        format = (d: Date) => d.toLocaleDateString();
      } else {
        start = new Date(now.getFullYear(), 0, 1);
        format = (d: Date) => d.toLocaleDateString();
      }
      // Group by day/hour
      const map = new Map<string, number>();
      for (const order of (orders || [])) {
        if (!order.created_at || !order.total) continue;
        const date = new Date(order.created_at);
        if (date < start) continue;
        let label = format(date);
        if (!map.has(label)) map.set(label, 0);
        map.set(label, (map.get(label) || 0) + (order.total || 0));
      }
      // Sort labels chronologically
      const labels = Array.from(map.keys()).sort((a, b) => {
        const da = new Date(a), db = new Date(b);
        return da.getTime() - db.getTime();
      });
      const data = labels.map(l => map.get(l) || 0);
      return { labels, data };
    }

    function openRevenueModal() {
      showRevenueModal = true;
      setTimeout(() => renderRevenueChart(), 0);
    }
    function closeRevenueModal() {
      showRevenueModal = false;
      if (revenueChartInstance) {
        revenueChartInstance.destroy();
        revenueChartInstance = null;
      }
    }
    function renderRevenueChart() {
      // Get valid completed orders
      const validOrders = (allOrders || []).filter((order: Order) => !order.deleted_at && order.status === 'completed');
      const { labels, data } = getRevenueDataByFilter(validOrders, revenueFilter);
      revenueChartLabels = labels;
      revenueChartData = data;
      const ctx = (document.getElementById('revenueChart') as HTMLCanvasElement)?.getContext('2d');
      if (!ctx) return;
      if (revenueChartInstance) revenueChartInstance.destroy();
      revenueChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
          labels: revenueChartLabels,
          datasets: [{
            label: 'Revenue',
            data: revenueChartData,
            borderColor: '#007bff',
            backgroundColor: 'rgba(0,123,255,0.1)',
            fill: true,
            tension: 0.3
          }]
        },
        options: {
          responsive: true,
          plugins: {
            legend: { display: false },
            tooltip: { enabled: true }
          },
          scales: {
            x: { title: { display: true, text: 'Date/Time' } },
            y: { title: { display: true, text: 'Revenue (R)' } }
          }
        }
      });
    }
    $: if (showRevenueModal) {
      setTimeout(() => renderRevenueChart(), 0);
    }
    function setRevenueFilter(filter: string) {
      revenueFilter = filter;
      setTimeout(() => renderRevenueChart(), 0);
    }

    function openDebtCreatedModal() {
      showDebtCreatedModal = true;
      fetchAndRenderDebtCreatedChart();
    }
    function closeDebtCreatedModal() {
      showDebtCreatedModal = false;
      if (debtCreatedChartInstance) {
        debtCreatedChartInstance.destroy();
        debtCreatedChartInstance = null;
      }
    }
    function setDebtCreatedFilter(filter: 'today' | 'week' | 'month' | 'year') {
      debtCreatedFilter = filter;
      fetchAndRenderDebtCreatedChart();
    }
    async function fetchAndRenderDebtCreatedChart() {
      // Fetch all debt transactions (type = 'debt')
      const { data: debtTxs, error: debtError } = await supabase
        .from('transactions')
        .select('created_at, amount')
        .eq('type', 'debt');
      // Fetch all debt payments (type = 'payment' or 'settlement' with positive amount)
      const { data: paidTxs, error: paidError } = await supabase
        .from('transactions')
        .select('created_at, amount, type')
        .in('type', ['payment', 'settlement'])
        .gt('amount', 0);
      if (debtError || paidError) {
        debtCreatedData = [];
        debtCreatedChartLabels = [];
        debtCreatedChartData = [];
        debtCreated = { today: 0, week: 0, month: 0, year: 0, all: 0 };
        return;
      }
      // Group by period
      const now = new Date();
      let start: Date;
      let format: (d: Date) => string;
      if (debtCreatedFilter === 'today') {
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        format = (d: Date) => d.getHours() + ':00';
      } else if (debtCreatedFilter === 'week') {
        start = new Date(now);
        start.setDate(now.getDate() - now.getDay());
        start.setHours(0,0,0,0);
        format = (d: Date) => d.toLocaleDateString();
      } else if (debtCreatedFilter === 'month') {
        start = new Date(now.getFullYear(), now.getMonth(), 1);
        format = (d: Date) => d.toLocaleDateString();
      } else {
        start = new Date(now.getFullYear(), 0, 1);
        format = (d: Date) => d.toLocaleDateString();
      }
      // Group debt created
      const debtMap = new Map<string, number>();
      for (const tx of debtTxs || []) {
        if (!tx.created_at || !tx.amount) continue;
        const date = new Date(tx.created_at);
        if (date < start) continue;
        const label = format(date);
        if (!debtMap.has(label)) debtMap.set(label, 0);
        debtMap.set(label, (debtMap.get(label) || 0) + Math.abs(tx.amount));
      }
      // Group debt paid
      const paidMap = new Map<string, number>();
      for (const tx of paidTxs || []) {
        if (!tx.created_at || !tx.amount) continue;
        const date = new Date(tx.created_at);
        if (date < start) continue;
        const label = format(date);
        if (!paidMap.has(label)) paidMap.set(label, 0);
        paidMap.set(label, (paidMap.get(label) || 0) + tx.amount);
      }
      // Union of all labels
      const allLabels = Array.from(new Set([...debtMap.keys(), ...paidMap.keys()])).sort((a, b) => {
        const da = Date.parse(a);
        const db = Date.parse(b);
        if (!isNaN(da) && !isNaN(db)) return da - db;
        return a.localeCompare(b);
      });
      debtCreatedChartLabels = allLabels;
      const debtCreatedSeries = allLabels.map(l => debtMap.get(l) || 0);
      const debtPaidSeries = allLabels.map(l => paidMap.get(l) || 0);
      debtCreatedChartData = debtCreatedSeries; // for legacy

      // For the card:
      debtCreated = {
        today: 0,
        week: 0,
        month: 0,
        year: 0,
        all: 0
      };
      for (const tx of debtTxs || []) {
        if (!tx.created_at || !tx.amount) continue;
        const date = new Date(tx.created_at);
        const absAmount = Math.abs(tx.amount);
        if (date >= new Date(now.getFullYear(), now.getMonth(), now.getDate())) debtCreated.today += absAmount;
        if (date >= new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay())) debtCreated.week += absAmount;
        if (date >= new Date(now.getFullYear(), now.getMonth(), 1)) debtCreated.month += absAmount;
        if (date >= new Date(now.getFullYear(), 0, 1)) debtCreated.year += absAmount;
        debtCreated.all += absAmount;
      }
      setTimeout(() => renderDebtCreatedChart(debtCreatedSeries, debtPaidSeries, allLabels), 0);
    }

    function renderDebtCreatedChart(
      debtCreatedSeries: number[],
      debtPaidSeries: number[],
      labels: string[]
    ) {
      const ctx = (document.getElementById('debtCreatedChart') as HTMLCanvasElement)?.getContext('2d');
      if (!ctx) return;
      if (debtCreatedChartInstance) debtCreatedChartInstance.destroy();
      debtCreatedChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
          labels: labels,
          datasets: [
            {
              label: 'Debt Created',
              data: debtCreatedSeries,
              borderColor: '#dc3545',
              backgroundColor: 'rgba(220,53,69,0.1)',
              fill: true,
              tension: 0.3
            },
            {
              label: 'Debt Paid',
              data: debtPaidSeries,
              borderColor: '#28a745',
              backgroundColor: 'rgba(40,167,69,0.1)',
              fill: true,
              tension: 0.3
            }
          ]
        },
        options: {
          responsive: true,
          plugins: {
            legend: { display: true },
            tooltip: { enabled: true }
          },
          scales: {
            x: { title: { display: true, text: 'Date/Time' } },
            y: { title: { display: true, text: 'Amount (R)' } }
          }
        }
      });
    }
    $: if (showDebtCreatedModal) {
      // setTimeout(() => renderDebtCreatedChart(), 0); // Removed: now requires arguments
    }
</script>

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

<div class="admin-container">


    {#if error}
        <div class="alert error" transition:fade>{error}</div>
    {/if}

    {#if success}
        <div class="alert success" transition:fade>{success}</div>
    {/if}

    {#if isAdmin}    <!-- Statistics Section -->
    <section id="stats" class="stats-section">
        <div class="section-header">
            <h2>Sales Statistics</h2>
            
        </div>
        <div class="stats-grid">
            <div class="stat-card">
                <h3>Total Orders</h3>
                <p class="stat-value">{stats.totalOrders}</p>
            </div>
            <button type="button" class="stat-card" on:click={openRevenueModal} style="cursor:pointer;">
                <h3>Total Revenue</h3>
                <p class="stat-value">R{stats.totalRevenue.toFixed(2)}</p>
            </button>
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
            <button type="button" class="stat-card" on:click={openDebtCreatedModal} style="cursor:pointer;">
                <h3>Debt Created</h3>
                <ul class="stat-list">
                  <li>Today: <strong>R{debtCreated.today.toFixed(2)}</strong></li>
                  <li>This Week: <strong>R{debtCreated.week.toFixed(2)}</strong></li>
                  <li>This Month: <strong>R{debtCreated.month.toFixed(2)}</strong></li>
                  <li>This Year: <strong>R{debtCreated.year.toFixed(2)}</strong></li>
                  <li>All Time: <strong>R{debtCreated.all.toFixed(2)}</strong></li>
                </ul>
            </button>
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
    {/if}


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
                                                disabled={order.status === 'cancelled'}
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
                                            {#if isAdmin}
                                                <button
                                                    class="delete-btn"
                                                    on:click={() => { showConfirmModal = true; orderIdToDelete = order.id; }}
                                                    style="margin-left: 0.5rem;"
                                                >
                                                    Delete
                                                </button>
                                            {/if}
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
                                        disabled={order.status === 'cancelled'}
                                    >
                                        <option value="pending">Pending</option>
                                        <option value="processing">Processing</option>
                                        <option value="completed">Completed</option>
                                        <option value="cancelled">Cancelled</option>
                                    </select>
                                </div>
                                <div class="admin-card-actions">
                                    <button class="view-details-btn" on:click={() => selectedOrder = order}>View Details</button>
                                    {#if isAdmin}
                                        <button class="delete-btn" on:click={() => { showConfirmModal = true; orderIdToDelete = order.id; }}>Delete</button>
                                    {/if}
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

    {#if showCancelConfirm}
      <div class="modal-backdrop" style="z-index: 3000;">
        <div class="modal-content" style="max-width: 400px; margin: 10vh auto;" role="dialog" aria-modal="true" aria-labelledby="cancel-modal-title">
          <div class="modal-header">
            <h2 id="cancel-modal-title" tabindex="-1">Cancel Order?</h2>
          </div>
          <div class="modal-body">
            <p>Are you sure you want to cancel this order? This action cannot be undone and will reapply all stock to inventory.</p>
            <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
              <button on:click={cancelCancelOrder}>No, keep order</button>
              <button on:click={confirmCancelOrder} class="danger">Yes, cancel order</button>
            </div>
          </div>
        </div>
      </div>
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
        
        <!-- Product Form (Add only) -->
        <div class="form-card">
          <button class="primary-btn" style="margin-bottom:1rem;" on:click={() => { editing = { name: '', description: '', price: 0, image_url: '', category: 'flower', thc_max: 0, cbd_max: 0, indica: 0, is_new: false, is_special: false }; showEditModal = true; isAddMode = true; }}>
            Add Product
          </button>
        </div>
        
        <!-- Edit/Add Product Modal -->
        {#if showEditModal && editing}
          <ProductEditModal
            product={editing}
            categories={categories}
            loading={loading}
            isAdd={isAddMode}
            on:save={async (e) => { editing = e.detail.product; await saveProduct(); closeEditModal(); isAddMode = false; }}
            on:cancel={() => { closeEditModal(); isAddMode = false; }}
            on:customprices={() => showCustomPrices = true}
          />
        {/if}
        
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
                            <th>Tags</th>
                            <th>Stock</th>
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
                                <td>
                                    {#if product.is_new}
                                      <span class="tag-badge new">New</span>
                                    {/if}
                                    {#if product.is_special}
                                      <span class="tag-badge special">Special</span>
                                    {/if}
                                </td>
                                <td>
                                    {#if product.is_special && product.special_price}
                                      <span style="text-decoration: line-through; color: #888;">R{product.price}</span>
                                      <span style="color: #e67e22; font-weight: bold; margin-left: 0.5em;">R{product.special_price}</span>
                                    {:else}
                                      R{product.price}
                                    {/if}
                                </td>
                                <td>{stockLevels[product.id] ?? 0}</td>
                                <td class="action-buttons">
                                    <button 
                                        class="edit-btn"
                                        on:click={() => { editing = product; showEditModal = true; isAddMode = false; }}
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
      <div class="modal-backdrop" role="button" tabindex="0" aria-label="Close custom prices modal" style="z-index:3000;" on:click={() => showCustomPrices = false} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') showCustomPrices = false; }}></div>
      <div
        class="modal custom-prices-modal"
        style="
          z-index: 3001;
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          min-width: 350px;
          max-width: 95vw;
          width: 600px;
          background: #fff;
          padding: 2rem;
          border-radius: 12px;
          box-shadow: 0 2px 16px rgba(0,0,0,0.2);
        "
        role="dialog"
        aria-modal="true"
      >
        <button class="close-btn" on:click={() => showCustomPrices = false} aria-label="Close custom prices modal" style="position:absolute;top:1rem;right:1rem;font-size:1.5rem;background:none;border:none;cursor:pointer;">×</button>
        <h3>Custom Prices for this Product</h3>
        <div style="margin-bottom:1rem;">
          <input type="text" placeholder="Search user by name or email..." bind:value={customPriceUserSearch} on:input={searchCustomPriceUsers} style="min-width:200px; width:100%;" />
          {#if customPriceUserLoading}
            <span>Searching...</span>
          {/if}
          {#if customPriceUserResults.length > 0}
            <ul style="background:#fff;border:1px solid #eee;max-height:120px;overflow-y:auto;margin:0;padding:0;list-style:none;">
              {#each customPriceUserResults as user}
                <li style="padding:0.5rem;">
                  <button type="button" style="all:unset;cursor:pointer;width:100%;display:block;" on:click={() => selectCustomPriceUser(user)} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') selectCustomPriceUser(user); }}>
                    {user.display_name || user.email} <span style="color:#888;font-size:0.9em;">({user.email})</span>
                  </button>
                </li>
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
        <div class="modal-backdrop" role="button" tabindex="0" aria-label="Close description modal" style="z-index:2100;" on:click={() => showDescriptionModal = false} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') showDescriptionModal = false; }}></div>
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

    {#if showRevenueModal}
      <div class="modal-backdrop" on:click={closeRevenueModal}></div>
      <div class="modal revenue-modal">
        <button class="close-btn" on:click={closeRevenueModal}>×</button>
        <h2>Revenue Over Time</h2>
        <div class="filter-btns">
          <button on:click={() => setRevenueFilter('today')} class:active={revenueFilter==='today'}>Today</button>
          <button on:click={() => setRevenueFilter('week')} class:active={revenueFilter==='week'}>This Week</button>
          <button on:click={() => setRevenueFilter('month')} class:active={revenueFilter==='month'}>This Month</button>
          <button on:click={() => setRevenueFilter('year')} class:active={revenueFilter==='year'}>This Year</button>
        </div>
        <canvas id="revenueChart" width="600" height="300"></canvas>
      </div>
    {/if}

    {#if showDebtCreatedModal}
      <div class="modal-backdrop" on:click={closeDebtCreatedModal}></div>
      <div class="modal revenue-modal">
        <button class="close-btn" on:click={closeDebtCreatedModal}>×</button>
        <h2>Debt Created Over Time</h2>
        <div class="filter-btns">
          <button on:click={() => setDebtCreatedFilter('today')} class:active={debtCreatedFilter==='today'}>Today</button>
          <button on:click={() => setDebtCreatedFilter('week')} class:active={debtCreatedFilter==='week'}>This Week</button>
          <button on:click={() => setDebtCreatedFilter('month')} class:active={debtCreatedFilter==='month'}>This Month</button>
          <button on:click={() => setDebtCreatedFilter('year')} class:active={debtCreatedFilter==='year'}>This Year</button>
        </div>
        <canvas id="debtCreatedChart" width="600" height="300"></canvas>
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
        overflow-x: hidden; /* Prevent horizontal scroll */
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
        .admin-container {
            padding: 1rem 0.5rem;
            
            max-width: 100vw;
            overflow-x: hidden;
        }
        .stats-grid, .stats-details {
            grid-template-columns: 1fr;
        }
        section {
            padding: 1rem 0;
        }
        .section-header {
            flex-direction: column;
            align-items: flex-start;
            gap: 1rem;
        }
        .table-responsive {
            width: 100vw;
            margin-left: -0.5rem;
            margin-right: -0.5rem;
            overflow-x: auto;
        }
        table {
            min-width: 700px;
            font-size: 0.95rem;
        }
        th, td {
            padding: 0.5rem;
        }
       
        .action-buttons {
            flex-direction: column;
            gap: 0.5rem;
        }
        .product-thumbnail {
            width: 40px;
        }
    }
    @media (max-width: 600px) {
        .admin-container {
            padding: 0.5rem 0.25rem;
        }
        .nav-content {
            flex-direction: column;
            align-items: flex-start;
            gap: 0.5rem;
        }
        .nav-links {
            flex-wrap: wrap;
            gap: 0.5rem;
        }
        .stats-grid, .stats-details {
            gap: 0.75rem;
        }
        .stat-card {
            padding: 0.75rem;
        }
        .modal.custom-prices-modal {
            padding: 1rem;
            min-width: 90vw;
        }
        .modal {
            padding: 1rem;
            min-width: 90vw;
        }
    }
    /* Show mobile card views for orders and products */
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
    /* Add mobile card view for products */
   
    .tag-badge {
      display: inline-block;
      padding: 0.2em 0.6em;
      margin-right: 0.3em;
      border-radius: 8px;
      font-size: 0.85em;
      font-weight: 600;
      color: #fff;
    }
    .tag-badge.new {
      background: #007bff;
    }
    .tag-badge.special {
      background: #e67e22;
    }
    
    .modal-backdrop {
      position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
    }
    .modal.revenue-modal {
      position: fixed;
      top: 50%; left: 50%;
      transform: translate(-50%, -50%);
      background: #fff;
      padding: 2rem;
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.2);
      z-index: 3001;
      min-width: 340px;
      max-width: 95vw;
      min-height: 340px;
    }
    .close-btn {
      position: absolute;
      top: 1rem;
      right: 1rem;
      background: none;
      border: none;
      font-size: 2rem;
      cursor: pointer;
    }
    .filter-btns {
      display: flex;
      gap: 1rem;
      margin-bottom: 1rem;
    }
    .filter-btns button {
      padding: 0.5rem 1rem;
      border: none;
      border-radius: 6px;
      background: #eee;
      cursor: pointer;
      font-weight: 500;
    }
    .filter-btns button.active {
      background: #007bff;
      color: #fff;
    }
</style>