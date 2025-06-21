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
  cashGiven: number = 0,
  isPosOrder: boolean = false,
  extraCashOption: 'change' | 'credit' = 'change'
): Promise<{ success: boolean; error: string | null; orderId?: string }> {
  try {
    if (!items || items.length === 0) {
      return { success: false, error: 'No items in cart' };
    }
    if (total < 0) {
      return { success: false, error: 'Invalid order total' };
    }

    let authUserId = null;
    if (userIdOverride) {
      // If an override is provided, assume it is an auth_user_id
      authUserId = userIdOverride;
    } else if (!guestInfo) {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return { success: false, error: 'User not authenticated and no guest info provided' };
      }
      authUserId = user.id;
    }

    if (!authUserId) {
      return { success: false, error: 'Could not determine user to charge order to.' };
    }

    // Prepare items for RPC
    const rpcItems = items.map(item => ({
      product_id: item.id,
      quantity: item.quantity,
      price: item.price
    }));

    // Call the atomic pay_order function
    const { data: orderId, error } = await supabase.rpc('pay_order', {
      p_user_id: authUserId,
      p_order_total: total,
      p_payment_amount: cashGiven,
      p_method: paymentMethod,
      p_items: rpcItems,
      p_extra_cash_option: extraCashOption,
      p_is_pos_order: isPosOrder
    });

    if (error) {
      console.error('pay_order error:', error);
      return { success: false, error: error.message };
    }

    return { success: true, error: null, orderId };
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
      .eq('id', orderId)
      .single();

    if (error) {
      console.error('Error fetching order:', error);
      return { error: 'Failed to fetch order details.' };
    }
    if (data && data.profiles) {
      data.user = data.profiles;
    }
    return { order: data as Order, error: null };
  } catch (err) {
    console.error('Unexpected error fetching order:', err);
    return { error: 'An unexpected error occurred.' };
  }
}

export async function getOrdersByEmail(email: string): Promise<{ orders: Order[], error: string | null }> {
  try {
    // 1. Fetch user id by email
    let userId: string | null = null;
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id')
      .eq('email', email)
      .maybeSingle();
    if (profile && profile.id) userId = profile.id;
    // 2. Fetch orders by guest_info->>email or user_id
    let orFilters = [`guest_info->>email.eq.${email}`];
    if (userId) orFilters.push(`user_id.eq.${userId}`);
    const { data, error } = await supabase
      .from('orders')
      .select(`*,order_items(*,products:product_id(name,image_url)),profiles:user_id(email,display_name,phone_number,address)`)
      .or(orFilters.join(','))
      .order('created_at', { ascending: false });
    if (error) {
      console.error('Error fetching orders:', error);
      return { orders: [], error: 'Failed to fetch orders.' };
    }
    // Map profiles to user
    const mapped = (data || []).map(order => ({
      ...order,
      user: order.profiles || undefined
    }));
    return { orders: mapped, error: null };
  } catch (err) {
    console.error('Unexpected error fetching orders:', err);
    return { orders: [], error: 'An unexpected error occurred.' };
  }
}

export async function getAllOrders(filters?: OrderFilters): Promise<{ orders: Order[], error: string | null }> {
  try {
    let query = supabase
      .from('orders')
      .select(`*,order_items(*,products:product_id(name,image_url)),profiles:user_id(email,display_name,phone_number,address)`);
    
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
        const { data: profiles, error: profilesError } = await supabase
          .from('profiles')
          .select('id')
          .or(`email.ilike.${searchTerm},display_name.ilike.${searchTerm}`);
        
        const userIds = profiles && Array.isArray(profiles) ? profiles.map((p: any) => p.id) : [];
        
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
    // Map profiles to user
    const mapped = (orders || []).map(order => ({
      ...order,
      user: order.profiles || undefined
    }));
    return { orders: mapped, error: null };
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

    return { success: true, error: null };
  } catch (err) {
    console.error('Unexpected error updating order status:', err);
    return { success: false, error: 'An unexpected error occurred.' };
  }
}

export async function payOrder(
  userId: string,
  orderTotal: number,
  paymentAmount: number,
  creditUsed: number,
  method: string,
  items: { product_id: string; quantity: number; price: number }[],
  extraCashOption: 'change' | 'credit' = 'change'
): Promise<{ success: boolean; error: string | null; orderId?: string }> {
  const { data, error } = await supabase.rpc('pay_order', {
    p_user_id: userId,
    p_order_total: orderTotal,
    p_payment_amount: paymentAmount,
    p_credit_used: creditUsed,
    p_method: method,
    p_items: items,
    p_extra_cash_option: extraCashOption
  });
  if (error) {
    return { success: false, error: error.message };
  }
  return { success: true, error: null, orderId: data };
}

export async function getUserBalance(userId: string): Promise<number> {
  // Sum all transactions for this user
  const { data, error } = await supabase
    .from('transactions')
    .select('amount')
    .eq('user_id', userId);
  if (error || !data) {
    console.error('Error fetching user balance:', error);
    return 0;
  }
  return data.reduce((sum, entry) => sum + Number(entry.amount), 0);
}

export async function getAllUserBalances(): Promise<Record<string, number>> {
  // Fetch all transactions and sum by user_id
  const { data, error } = await supabase
    .from('transactions')
    .select('user_id, amount');
  if (error || !data) return {};
  const balances: Record<string, number> = {};
  for (const entry of data) {
    if (!entry.user_id) continue;
    balances[entry.user_id] = (balances[entry.user_id] || 0) + Number(entry.amount);
  }
  return balances;
}

export async function reapplyOrderStock(orderId: string): Promise<{ success: boolean; error: string | null }> {
  try {
    // Fetch order items
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('order_items (product_id, quantity)')
      .eq('id', orderId)
      .single();
    if (orderError || !order || !order.order_items) {
      return { success: false, error: 'Failed to fetch order items for stock reapplication.' };
    }
    const shopId = await getLocationId('shop');
    if (!shopId) {
      return { success: false, error: 'Shop location not found.' };
    }
    for (const item of order.order_items) {
      // Get current stock
      const { data: stockData } = await supabase
        .from('stock_levels')
        .select('quantity')
        .eq('product_id', item.product_id)
        .eq('location_id', shopId)
        .single();
      const newQty = (stockData?.quantity ?? 0) + item.quantity;
      await supabase
        .from('stock_levels')
        .upsert({ product_id: item.product_id, location_id: shopId, quantity: newQty }, { onConflict: 'product_id,location_id' });
    }
    return { success: true, error: null };
  } catch (err) {
    console.error('Error reapplying stock:', err);
    return { success: false, error: 'An error occurred while reapplying stock.' };
  }
}

export async function getTopBuyingUsers(limit = 10) {
  const { data, error } = await supabase.rpc('get_top_buyers', { p_limit: limit });

  if (error) {
    console.error('Error fetching top buyers:', error);
    return [];
  }
  return data || [];
}

export async function getUsersWithMostDebt(limit = 10) {
  const { data, error } = await supabase.rpc('get_users_with_most_debt', { p_limit: limit });

  if (error) {
    console.error('Error fetching users with most debt:', error);
    return [];
  }
  return data || [];
}

// Fetch all orders with their items, profiles, etc. and merge payment summary
export async function getAllOrdersWithPaymentSummary() {
  const { data, error } = await supabase.rpc('get_all_orders_with_payment_summary');

  if (error) {
    console.error('Error fetching orders with payment summary:', error);
    return [];
  }

  return data || [];
}

// Fetch single order with its items, profile, etc. and merge payment summary
export async function getOrderWithPaymentSummary(orderId: string) {
  try {
    // First, get the basic order details
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select(`*, order_items(*, products(*)), profiles:user_id(*)`)
      .eq('id', orderId)
      .single();
  
    if (orderError) throw orderError;
  
    // Now, call the secure function to get the payment summary
    const { data: summary, error: summaryError } = await supabase.rpc(
      'get_order_payment_summary',
      { p_order_id: orderId }
    );
  
    if (summaryError) throw summaryError;
  
    // The RPC returns an array with one object, so we take the first element
    const paymentSummary = Array.isArray(summary) ? summary[0] : summary;
  
    return { 
      data: { ...order, payment_summary: paymentSummary }, 
      error: null 
    };
  
  } catch (err: any) {
    console.error('Error fetching order with payment summary:', err);
    return { data: null, error: err.message || 'An unexpected error occurred.' };
  }
}

/**
 * Returns the user's available credit (positive = credit, negative = debt, zero = settled).
 * Sums all transactions for the user.
 */
export async function getUserAvailableCredit(userId: string): Promise<number> {
  const { data, error } = await supabase
    .from('transactions')
    .select('amount')
    .eq('user_id', userId);
  if (error || !data) {
    console.error('Error fetching user available credit:', error);
    return 0;
  }
  // Net sum: positive = credit, negative = debt
  return data.reduce((sum, entry) => sum + Number(entry.amount), 0);
} 