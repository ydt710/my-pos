import { supabase } from '../supabase';
import type { CartItem, Order, OrderItem } from '../types';

export async function createOrder(
  total: number, 
  items: CartItem[]
): Promise<{ success: boolean; error: string | null }> {
  try {
    // Start a transaction
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({ total })
      .select()
      .single();

    if (orderError) {
      console.error('Checkout error:', orderError);
      return { success: false, error: 'Failed to create order. Please try again.' };
    }

    // Process each item in the cart
    for (const item of items) {
      // Get current product quantity with a lock
      const { data: product, error: fetchError } = await supabase
        .from('products')
        .select('quantity')
        .eq('id', item.id)
        .single();

      if (fetchError) {
        console.error('Error fetching product:', fetchError);
        return { 
          success: false, 
          error: 'Failed to fetch product details. Please try again.' 
        };
      }

      if (!product) {
        return { 
          success: false, 
          error: `Product ${item.name} not found. Please try again.` 
        };
      }

      // Calculate new quantity and check stock
      const newQuantity = product.quantity - item.quantity;
      if (newQuantity < 0) {
        return { 
          success: false, 
          error: `Insufficient quantity for ${item.name}. Only ${product.quantity} available.` 
        };
      }

      // Insert order item
      const { error: itemError } = await supabase.from('order_items').insert({
        order_id: order.id,
        product_id: item.id,
        quantity: item.quantity,
        price: item.price
      });
      
      if (itemError) {
        console.error('Error adding order item:', itemError);
        return { 
          success: false, 
          error: 'Failed to add items to order. Please contact support.' 
        };
      }

      // Update product quantity with optimistic locking
      const { error: updateError } = await supabase
        .from('products')
        .update({ 
          quantity: newQuantity,
          updated_at: new Date().toISOString()
        })
        .eq('id', item.id)
        .eq('quantity', product.quantity); // Ensure quantity hasn't changed
        
      if (updateError) {
        console.error('Error updating product quantity:', updateError);
        return { 
          success: false, 
          error: 'Failed to update product quantities. Please try again.' 
        };
      }
    }

    return { success: true, error: null };
  } catch (err) {
    console.error('Unexpected error in checkout:', err);
    return { 
      success: false, 
      error: 'An unexpected error occurred. Please try again later.' 
    };
  }
} 