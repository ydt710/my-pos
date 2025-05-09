import { writable } from 'svelte/store';
import type { CartItem, Product } from '../types';
import { supabase } from '$lib/supabase';

// Create a notification store for cart messages
export const cartNotification = writable<{ type: 'error' | 'warning' | 'success', message: string } | null>(null);

// Create the cart store
function createCartStore() {
  const { subscribe, set, update } = writable<CartItem[]>([]);

  return {
    subscribe,
    addItem: async (product: Product) => {
      if (product.quantity <= 0) {
        cartNotification.set({ type: 'error', message: 'This item is out of stock.' });
        return false;
      }

      // Check current stock level
      const { data: currentProduct, error } = await supabase
        .from('products')
        .select('quantity')
        .eq('id', product.id)
        .single();

      if (error || !currentProduct) {
        cartNotification.set({ type: 'error', message: 'Failed to check stock level.' });
        return false;
      }

      let success = true;
      update(items => {
        const existing = items.find(item => item.id === product.id);
        const currentStock = currentProduct.quantity;
        const requestedQuantity = product.quantity || 1; // Fallback to 1 if not specified

        if (existing) {
          // Check if adding more would exceed stock
          const newQuantity = existing.quantity + requestedQuantity;
          if (newQuantity > currentStock) {
            cartNotification.set({ 
              type: 'warning', 
              message: `Only ${currentStock} items available in stock.`
            });
            success = false;
            return items;
          }
          
          // Update existing item quantity
          return items.map(item =>
            item.id === product.id
              ? { ...item, quantity: Math.min(currentStock, newQuantity) }
              : item
          );
        } else {
          // Check if initial quantity would exceed stock
          if (requestedQuantity > currentStock) {
            cartNotification.set({ 
              type: 'warning', 
              message: `Only ${currentStock} items available in stock.`
            });
            // Add item with maximum available quantity
            return [...items, { ...product, quantity: currentStock }];
          }
          
          // Add new item with requested quantity
          return [...items, { ...product, quantity: requestedQuantity }];
        }
      });

      if (success) {
        cartNotification.set({ 
          type: 'success', 
          message: 'Item added to cart.' 
        });
        // Clear success message after 3 seconds
        setTimeout(() => cartNotification.set(null), 3000);
      }

      return success;
    },
    updateQuantity: async (productId: number, newQuantity: number) => {
      if (newQuantity < 1) {
        cartNotification.set({ type: 'error', message: 'Quantity must be at least 1.' });
        return false;
      }

      // Check current stock level
      const { data: currentProduct, error } = await supabase
        .from('products')
        .select('quantity')
        .eq('id', productId)
        .single();

      if (error || !currentProduct) {
        cartNotification.set({ type: 'error', message: 'Failed to check stock level.' });
        return false;
      }

      if (newQuantity > currentProduct.quantity) {
        cartNotification.set({ 
          type: 'warning', 
          message: `Only ${currentProduct.quantity} items available in stock.` 
        });
        // Update to maximum available
        update(items => {
          return items.map(item =>
            item.id === productId
              ? { ...item, quantity: currentProduct.quantity }
              : item
          );
        });
        return false;
      }

      update(items => {
        return items.map(item =>
          item.id === productId
            ? { ...item, quantity: newQuantity }
            : item
        );
      });
      return true;
    },
    removeItem: (productId: number) => {
      update(items => items.filter(item => item.id !== productId));
    },
    clearCart: () => {
      set([]);
      cartNotification.set(null);
    },
    getTotal: (items: CartItem[]) => {
      return items.reduce((total, item) => total + item.price * item.quantity, 0);
    },
    getItemCount: (items: CartItem[]) => {
      return items.reduce((count, item) => count + item.quantity, 0);
    }
  };
}

export const cartStore = createCartStore(); 