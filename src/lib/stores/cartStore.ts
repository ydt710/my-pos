import { writable } from 'svelte/store';
import type { CartItem, Product, User } from '$lib/types/index';
import { supabase } from '$lib/supabase';
import { writable as writableStore } from 'svelte/store';
import { getStock } from '$lib/services/stockService';
import { get } from 'svelte/store';

// Create a notification store for cart messages
export const cartNotification = writable<{ type: 'error' | 'warning' | 'success', message: string } | null>(null);

// Create the cart store
function createCartStore() {
  const { subscribe, set, update } = writable<CartItem[]>([]);

  return {
    subscribe,
    addItem: async (product: Product) => {
      // Check current shop stock level
      const currentStock = await getStock(product.id, 'shop');
      if (currentStock <= 0) {
        cartNotification.set({ type: 'error', message: 'This item is out of stock.' });
        return false;
      }

      // Use custom price if available for selected POS user
      let selectedUserId = null;
      if (typeof window !== 'undefined') {
        const stored = localStorage.getItem('selectedPosUser');
        if (stored) {
          try {
            const user = JSON.parse(stored);
            selectedUserId = user?.id;
          } catch {}
        }
      }
      let price = product.price;
      if (selectedUserId) {
        const prices = get(customPrices);
        if (prices[product.id]) price = prices[product.id];
      }

      let success = true;
      update(items => {
        const existing = items.find(item => String(item.id) === String(product.id));
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
            String(item.id) === String(product.id)
              ? { ...item, quantity: Math.min(currentStock, newQuantity), price }
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
            return [...items, { ...product, quantity: currentStock, price }];
          }
          
          // Add new item with requested quantity
          return [...items, { ...product, quantity: requestedQuantity, price }];
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
    updateQuantity: async (productId: string | number, newQuantity: number) => {
      if (newQuantity < 1) {
        cartNotification.set({ type: 'error', message: 'Quantity must be at least 1.' });
        return false;
      }

      // Check current shop stock level
      const currentStock = await getStock(productId, 'shop');
      if (currentStock <= 0) {
        cartNotification.set({ type: 'error', message: 'This item is out of stock.' });
        return false;
      }

      if (newQuantity > currentStock) {
        cartNotification.set({ 
          type: 'warning', 
          message: `Only ${currentStock} items available in stock.` 
        });
        // Update to maximum available
        update(items => {
          return items.map(item =>
            String(item.id) === String(productId)
              ? { ...item, quantity: currentStock }
              : item
          );
        });
        return false;
      }

      update(items => {
        return items.map(item =>
          String(item.id) === String(productId)
            ? { ...item, quantity: newQuantity }
            : item
        );
      });
      return true;
    },
    removeItem: (productId: string | number) => {
      update(items => items.filter(item => String(item.id) !== String(productId)));
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

export type PosUser = User | null;

function createSelectedPosUser() {
  let initial: PosUser = null;
  if (typeof localStorage !== 'undefined') {
    const stored = localStorage.getItem('selectedPosUser');
    if (stored) {
      try {
        initial = JSON.parse(stored);
      } catch {}
    }
  }
  const { subscribe, set } = writableStore<PosUser>(initial);
  return {
    subscribe,
    set: (val: PosUser) => {
      if (typeof localStorage !== 'undefined') {
        if (val) {
          localStorage.setItem('selectedPosUser', JSON.stringify(val));
        } else {
          localStorage.removeItem('selectedPosUser');
        }
      }
      set(val);
    },
    clear: () => {
      if (typeof localStorage !== 'undefined') {
        localStorage.removeItem('selectedPosUser');
      }
      set(null);
    }
  };
}

export const selectedPosUser = createSelectedPosUser();

// Create a store to check if current user is POS or admin
export const isPosOrAdmin = writableStore<boolean>(false);

// Update isPosOrAdmin when selectedPosUser changes or when user is admin
export async function updateIsPosOrAdmin() {
  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    // Check if user is admin
    const isAdmin = !!user.user_metadata?.is_admin;
    if (isAdmin) {
      isPosOrAdmin.set(true);
      return;
    }
    // Check if user is POS
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('auth_user_id', user.id)
      .single();
    isPosOrAdmin.set(profile?.role === 'pos');
  } else {
    isPosOrAdmin.set(false);
  }
}

// Store for user-specific custom prices: { [productId]: customPrice }
export const customPrices = writableStore<{ [productId: string]: number }>({});

// Fetch all custom prices for a user and update the store
export async function fetchCustomPricesForUser(userId: string) {
  if (!userId) { customPrices.set({}); return; }
  const { data, error } = await supabase
    .from('user_product_prices')
    .select('product_id, custom_price')
    .eq('user_id', userId);
  if (error) { customPrices.set({}); return; }
  const priceMap = Object.fromEntries((data || []).map(row => [row.product_id, Number(row.custom_price)]));
  customPrices.set(priceMap);
}

// Helper to get the effective price for a product and user
export function getEffectivePrice(product: Product, userId?: string): number {
  const prices = get(customPrices);
  return (userId && prices[product.id]) ? prices[product.id] : product.price;
} 