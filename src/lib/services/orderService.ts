import { supabase } from '../supabase';
import type { CartItem } from '../types/index';
import type { Order, OrderItem, GuestInfo, OrderStatus, OrderFilters } from '../types/orders';
import { getLocationId } from './stockService';

// Helper function to generate formatted order number
function generateOrderNumber(timestamp: Date): string {
  const year = timestamp.getFullYear().toString().slice(-2);
  const month = (timestamp.getMonth() + 1).toString().padStart(2, '0');
  const day = timestamp.getDate().toString().padStart(2, '0');
  const hours = timestamp.getHours().toString().padStart(2, '0');
  const minutes = timestamp.getMinutes().toString().padStart(2, '0');
  const seconds = timestamp.getSeconds().toString().padStart(2, '0');
  
  // Format: YYMMDDHHmmss
  return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

export async function createOrder(
  total: number, 
  items: CartItem[],
  guestInfo?: GuestInfo,
  userIdOverride?: string,
  paymentMethod: string = 'cash',
  debt: number = 0,
  cashGiven: number = 0,
  changeGiven: number = 0,
  isPosOrder: boolean = false,
  extraCashOption: 'change' | 'credit' = 'change',
  currentUserDebt: number = 0, // Pass this from frontend if needed
  creditUsed: number = 0
): Promise<{ success: boolean; error: string | null; orderId?: string }> {
  try {
    // Validate items before proceeding
    if (!items || items.length === 0) {
      return { success: false, error: 'No items in cart' };
    }

    // Validate total
    if (total <= 0) {
      return { success: false, error: 'Invalid order total' };
    }

    // Get current user if not a guest order
    let userId = null;
    if (userIdOverride) {
      userId = userIdOverride;
    } else if (!guestInfo) {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return { success: false, error: 'User not authenticated and no guest info provided' };
      }
      userId = user.id;
    }

    // Start a transaction by creating the order first
    const orderTimestamp = new Date();
    const orderNumber = generateOrderNumber(orderTimestamp);
    
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        total: total,
        status: 'pending',
        user_id: userId,
        guest_info: guestInfo ? {
          email: guestInfo.email.toLowerCase().trim(),
          name: guestInfo.name.trim(),
          phone: guestInfo.phone.trim(),
          address: guestInfo.address.trim()
        } : null,
        created_at: orderTimestamp.toISOString(),
        updated_at: orderTimestamp.toISOString(),
        order_number: orderNumber,
        payment_method: paymentMethod,
        debt: debt,
        cash_given: cashGiven,
        change_given: changeGiven,
        is_pos_order: isPosOrder
      })
      .select()
      .single();

    if (orderError) {
      console.error('Checkout error:', orderError);
      return { success: false, error: 'Failed to create order. Please try again.' };
    }

    if (!order) {
      return { success: false, error: 'Failed to create order record' };
    }

    // Process each item in the cart
    const shopId = await getLocationId('shop');
    if (!shopId) {
      // Rollback by deleting the order
      await supabase.from('orders').delete().eq('id', order.id);
      return { success: false, error: 'Shop location not found.' };
    }
    for (const item of items) {
      // Get current shop stock level
      const { data: shopStock, error: fetchError } = await supabase
        .from('stock_levels')
        .select('quantity')
        .eq('product_id', item.id)
        .eq('location_id', shopId)
        .single();

      if (fetchError) {
        console.error('Error fetching shop stock:', fetchError);
        // Rollback by deleting the order
        await supabase.from('orders').delete().eq('id', order.id);
        return { 
          success: false, 
          error: 'Failed to fetch shop stock. Please try again.' 
        };
      }

      if (!shopStock) {
        // Rollback by deleting the order
        await supabase.from('orders').delete().eq('id', order.id);
        return { 
          success: false, 
          error: `Product ${item.name} not found in shop stock. Please try again.` 
        };
      }

      // Calculate new quantity and check stock
      const newQuantity = shopStock.quantity - item.quantity;
      if (newQuantity < 0) {
        // Rollback by deleting the order
        await supabase.from('orders').delete().eq('id', order.id);
        return { 
          success: false, 
          error: `Insufficient quantity for ${item.name}. Only ${shopStock.quantity} available in shop.` 
        };
      }

      // Insert order item
      const { error: itemError } = await supabase
        .from('order_items')
        .insert({
          order_id: order.id,
          product_id: item.id,
          quantity: item.quantity,
          price: item.price,
          created_at: new Date().toISOString()
        });
      
      if (itemError) {
        console.error('Error adding order item:', itemError);
        // Rollback by deleting the order
        await supabase.from('orders').delete().eq('id', order.id);
        return { 
          success: false, 
          error: 'Failed to add items to order. Please contact support.' 
        };
      }

      // Update shop stock_levels
      const { error: updateError } = await supabase
        .from('stock_levels')
        .update({ quantity: newQuantity })
        .eq('product_id', item.id)
        .eq('location_id', shopId);
        
      if (updateError) {
        console.error('Error updating shop stock quantity:', {
          error: updateError,
          productId: item.id,
          newQuantity
        });
        // Rollback by deleting the order
        await supabase.from('orders').delete().eq('id', order.id);
        return { 
          success: false, 
          error: `Failed to update shop stock for ${item.name}. Please try again.` 
        };
      }
    }

    // Log successful order creation
    console.log('Order created successfully:', {
      orderId: order.id,
      orderNumber: order.order_number,
      isGuest: !!guestInfo,
      guestEmail: guestInfo?.email
    });

    // Ledger logic for POS/credit orders
    const GUEST_PROFILE_ID = 'ab54f66c-fa1c-40d2-ad2a-d9d5c1603e0f';
    // Only run ledger logic for real customers, not for the float/guest account
    if (userId && isPosOrder) {
      const totalDue = total + Math.abs(currentUserDebt || 0);
      const netPayment = Math.min((cashGiven || 0) - (changeGiven || 0), totalDue);
      const overpayment = Math.max(0, (cashGiven || 0) - totalDue);
      const totalPaid = (netPayment || 0) + (creditUsed || 0);

      // Only log a debt if the order is not fully paid
      if (totalPaid < total) {
        // Log the remaining debt
        await supabase.from('credit_ledger').insert({
          user_id: userId,
          type: 'order',
          amount: -(total - totalPaid), // negative for the unpaid portion
          order_id: order.id,
          note: 'Order placed (POS/credit, partial payment)'
        });
      }

      // Log credit used if any
      if (creditUsed > 0) {
        await supabase.from('credit_ledger').insert({
          user_id: userId,
          type: 'credit_used',
          amount: -creditUsed, // NEGATIVE: reduces credit
          order_id: order.id,
          note: 'Credit used for order'
        });
      }

      // Log payment if any cash was given
      if (netPayment > 0) {
        await supabase.from('credit_ledger').insert({
          user_id: userId,
          type: 'payment',
          amount: netPayment,
          order_id: order.id,
          note: 'Order payment'
        });
      }

      // Log overpayment as credit if requested
      if (extraCashOption === 'credit' && overpayment > 0) {
        await supabase.from('credit_ledger').insert({
          user_id: userId,
          type: 'payment',
          amount: overpayment,
          note: 'Overpayment credited to account'
        });
      }
    }

    return { success: true, error: null, orderId: order.id };
  } catch (err) {
    console.error('Unexpected error in checkout:', err);
    return { 
      success: false, 
      error: 'An unexpected error occurred. Please try again later.' 
    };
  }
}

export async function getOrder(orderId: string): Promise<{ order?: Order, error: string | null }> {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select(`
        *,
        order_items (
          *,
          product:products (
            name,
            image_url
          )
        )
      `)
      .eq('id', orderId)
      .single();

    if (error) {
      console.error('Error fetching order:', error);
      return { error: 'Failed to fetch order details.' };
    }

    return { order: data as Order, error: null };
  } catch (err) {
    console.error('Unexpected error fetching order:', err);
    return { error: 'An unexpected error occurred.' };
  }
}

export async function getOrdersByEmail(email: string): Promise<{ orders: Order[], error: string | null }> {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select(`
        *,
        order_items (
          *,
          product:products (
            name,
            image_url
          )
        )
      `)
      .or(`guest_info->>'email'.eq.${email},user_id.eq.(select id from auth.users where email = ${email})`)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching orders:', error);
      return { orders: [], error: 'Failed to fetch orders.' };
    }

    return { orders: data as Order[], error: null };
  } catch (err) {
    console.error('Unexpected error fetching orders:', err);
    return { orders: [], error: 'An unexpected error occurred.' };
  }
}

export async function getAllOrders(filters?: OrderFilters): Promise<{ orders: Order[], error: string | null }> {
  try {
    let query = supabase
      .from('orders')
      .select(`
        *,
        order_items (
          *,
          products (
            name,
            image_url
          )
        )
      `);

    // Apply filters
    if (filters) {
      if (filters.status) {
        query = query.eq('status', filters.status);
      }
      
      if (filters.dateFrom) {
        query = query.gte('created_at', filters.dateFrom);
      }
      
      if (filters.dateTo) {
        query = query.lte('created_at', filters.dateTo);
      }
      
      if (filters.search) {
        const searchTerm = `%${filters.search}%`;
        // Step 1: Find matching user IDs in profiles
        let userIds: string[] = [];
        const { data: profiles, error: profilesError } = await supabase
          .from('profiles')
          .select('id')
          .or(`email.ilike.${searchTerm},display_name.ilike.${searchTerm}`);
        if (profiles && Array.isArray(profiles)) {
          userIds = profiles.map((p: any) => p.id);
        }
        // Step 2: Build orFilters
        let orFilters = [
          `guest_info->>email.ilike.${searchTerm}`,
          `guest_info->>name.ilike.${searchTerm}`
        ];
        if (userIds.length > 0) {
          orFilters.push(`user_id.in.(${userIds.join(',')})`);
        }
        query = query.or(orFilters.join(','));
      }

      // Apply sorting
      if (filters.sortBy) {
        query = query.order(filters.sortBy, { 
          ascending: filters.sortOrder === 'asc'
        });
      } else {
        query = query.order('created_at', { ascending: false });
      }
    } else {
      query = query.order('created_at', { ascending: false });
    }

    const { data: orders, error: ordersError } = await query;

    if (ordersError) {
      console.error('Error fetching orders:', ordersError);
      return { orders: [], error: 'Failed to fetch orders.' };
    }

    // Get unique user IDs from orders
    const userIds = orders
      .filter(order => order.user_id)
      .map(order => order.user_id);

    // Fetch profiles for registered users
    let profilesMap = new Map();
    if (userIds.length > 0) {
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, email, display_name, phone_number, address')
        .in('id', userIds);

      if (profilesError) {
        console.error('Error fetching profiles:', profilesError);
      } else if (profiles) {
        profilesMap = new Map(
          profiles.map(profile => [profile.id, profile])
        );
      }
    }

    // Transform orders to include user data in the expected format
    const transformedOrders = orders.map(order => {
      if (order.user_id && profilesMap.has(order.user_id)) {
        const profile = profilesMap.get(order.user_id);
        return {
          ...order,
          user: {
            email: profile.email,
            display_name: profile.display_name,
            phone_number: profile.phone_number,
            address: profile.address
          }
        };
      }
      return order;
    });

    return { orders: transformedOrders, error: null };
  } catch (err) {
    console.error('Unexpected error fetching orders:', err);
    return { orders: [], error: 'An unexpected error occurred.' };
  }
}

export async function updateOrderStatus(
  orderId: string, 
  status: OrderStatus
): Promise<{ success: boolean; error: string | null }> {
  try {
    // Update the order status
    const { error } = await supabase
      .from('orders')
      .update({ 
        status,
        updated_at: new Date().toISOString()
      })
      .eq('id', orderId);

    if (error) {
      console.error('Error updating order status:', error);
      return { success: false, error: 'Failed to update order status.' };
    }

    // --- NEW: Insert ledger entries for normal user orders on completion ---
    if (status === 'completed') {
      // Fetch the order
      const { data: order, error: orderFetchError } = await supabase
        .from('orders')
        .select('*')
        .eq('id', orderId)
        .single();
      if (!order || orderFetchError) {
        return { success: false, error: 'Order not found for ledger update.' };
      }
      // Only for registered users (not POS/credit)
      if (order.user_id && !order.is_pos_order) {
        // Sum all credit_used and payment ledger entries for this order
        const { data: ledgerEntries } = await supabase
          .from('credit_ledger')
          .select('amount, type')
          .eq('order_id', orderId);
        const totalPaid = (ledgerEntries || [])
          .filter(e => e.type === 'payment' || e.type === 'credit_used')
          .reduce((sum, e) => sum + Math.abs(Number(e.amount)), 0);
        if (totalPaid < order.total) {
          // Only log payment for the remaining amount
          const paymentToLog = order.total - totalPaid;
          if (paymentToLog > 0) {
            await supabase.from('credit_ledger').insert({
              user_id: order.user_id,
              type: 'payment',
              amount: paymentToLog,
              order_id: order.id,
              note: 'Cash collected on order completion'
            });
          }
        }
        // else: already fully paid, do not log another payment
      }
    }

    return { success: true, error: null };
  } catch (err) {
    console.error('Unexpected error updating order status:', err);
    return { success: false, error: 'An unexpected error occurred.' };
  }
}

export async function logPaymentToLedger(userId: string, paymentAmount: number, orderId?: string, note?: string, method?: string) {
  return await supabase.from('credit_ledger').insert({
    user_id: userId,
    type: 'payment',
    amount: paymentAmount, // positive for payment
    order_id: orderId,
    note: note || 'Payment received',
    method: method || null
  });
}

// Returns the user's net balance (credit minus debt). Sums all ledger entries.
// 'order' and 'credit_used' are negative, 'payment' is positive.
export async function getUserBalance(userId: string): Promise<number> {
  const { data, error } = await supabase
    .from('credit_ledger')
    .select('amount, type')
    .eq('user_id', userId);

  if (error || !data) {
    console.error('Error fetching ledger:', error);
    return 0;
  }

  // Sum all amounts as they are (order, credit_used, payment, refund, etc.)
  // This ensures that after a credit-paid order, the balance is correct (zero if fully paid)
  return data.reduce((sum, entry) => sum + Number(entry.amount), 0);
}

// Batch fetch all user balances as a map { user_id: balance }
export async function getAllUserBalances(): Promise<Record<string, number>> {
  const { data, error } = await supabase
    .from('credit_ledger')
    .select('user_id, amount');
  if (error || !data) return {};
  const balances: Record<string, number> = {};
  for (const entry of data) {
    if (!entry.user_id) continue;
    balances[entry.user_id] = (balances[entry.user_id] || 0) + entry.amount;
  }
  return balances;
}

// Get top buying users by total completed order value
export async function getTopBuyingUsers(limit = 10) {
  const { data, error } = await supabase
    .from('orders')
    .select('user_id, total')
    .eq('status', 'completed');

  if (error || !data) return [];

  // Aggregate totals per user
  const totals: Record<string, number> = {};
  for (const order of data) {
    if (!order.user_id) continue;
    totals[order.user_id] = (totals[order.user_id] || 0) + Number(order.total);
  }

  // Convert to array and sort
  const sorted: { user_id: string; total: number; email?: string; name?: string }[] = Object.entries(totals)
    .map(([user_id, total]) => ({ user_id, total: Number(total) }))
    .sort((a, b) => b.total - a.total)
    .slice(0, limit);

  // Fetch user emails and names
  if (sorted.length > 0) {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, email, display_name')
      .in('id', sorted.map(u => u.user_id));
    for (const user of sorted) {
      const profile = profiles?.find(p => p.id === user.user_id);
      user.email = profile?.email || '';
      user.name = profile?.display_name || '';
    }
  }

  return sorted;
}

// Get users with most debt (lowest balances)
export async function getUsersWithMostDebt(limit = 10) {
  const { data, error } = await supabase
    .from('credit_ledger')
    .select('user_id, amount');

  if (error || !data) return [];

  // Aggregate balances per user
  const balances: Record<string, number> = {};
  for (const entry of data) {
    if (!entry.user_id) continue;
    balances[entry.user_id] = (balances[entry.user_id] || 0) + Number(entry.amount);
  }

  // Convert to array and sort by most negative
  const sorted: { user_id: string; balance: number; email?: string; name?: string }[] = Object.entries(balances)
    .map(([user_id, balance]) => ({ user_id, balance: Number(balance) }))
    .sort((a, b) => a.balance - b.balance)
    .slice(0, limit);

  // Fetch user emails and names
  if (sorted.length > 0) {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, email, display_name')
      .in('id', sorted.map(u => u.user_id));
    for (const user of sorted) {
      const profile = profiles?.find(p => p.id === user.user_id);
      user.email = profile?.email || '';
      user.name = profile?.display_name || '';
    }
  }

  return sorted;
} 