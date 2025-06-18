import { writable, derived } from 'svelte/store';
import type { CartItem, Product, User } from '$lib/types/index';
import { supabase } from '$lib/supabase';
import { writable as writableStore, get as getStore } from 'svelte/store';
import { getStock } from '$lib/services/stockService';
import { get } from 'svelte/store';

// Store for user-specific custom prices: { [productId]: customPrice }
export const customPrices = writableStore<{ [productId: string]: number }>({});

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

// --- Notification Queue ---
interface Notification {
  type: 'error' | 'warning' | 'success';
  message: string;
  duration?: number;
}
const notificationQueue: Notification[] = [];
export const cartNotification = writable<Notification | null>(null);
let notificationTimeout: NodeJS.Timeout | null = null;
function showNextNotification() {
  if (notificationQueue.length === 0) {
    cartNotification.set(null);
    return;
  }
  const next = notificationQueue.shift()!;
  cartNotification.set(next);
  if (notificationTimeout) clearTimeout(notificationTimeout);
  notificationTimeout = setTimeout(() => {
    showNextNotification();
  }, next.duration ?? 3000);
}
function queueNotification(n: Notification) {
  notificationQueue.push(n);
  if (getStore(cartNotification) === null) {
    showNextNotification();
  }
}

// --- Cart Persistence ---
const CART_KEY = 'cartItems';
function saveCartToStorage(items: CartItem[]) {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(CART_KEY, JSON.stringify(items));
  }
}
function loadCartFromStorage(): CartItem[] {
  if (typeof localStorage !== 'undefined') {
    const stored = localStorage.getItem(CART_KEY);
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch {}
    }
  }
  return [];
}

// --- Cart Store ---
function createCartStore() {
  const { subscribe, set, update } = writable<CartItem[]>(loadCartFromStorage());
  
  subscribe(items => saveCartToStorage(items));

  // Add item to cart
  async function addItem(product: Product) {
    const controller = new AbortController();
    try {
      const currentStock = await getStock(product.id, 'shop', { signal: controller.signal });
      if (currentStock <= 0) {
        queueNotification({ type: 'error', message: 'This item is out of stock.' });
        return false;
      }
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
      let requestedQuantity = product.quantity || 1;
      let price = getEffectivePrice(product, selectedUserId, requestedQuantity);
      let success = true;
      update(items => {
        const existing = items.find(item => String(item.id) === String(product.id));
        if (existing) {
          const newQuantity = existing.quantity + requestedQuantity;
          if (newQuantity > currentStock) {
            queueNotification({ type: 'warning', message: `Only ${currentStock} items available in stock.` });
            success = false;
            return items;
          }
          price = getEffectivePrice(product, selectedUserId, newQuantity);
          return items.map(item =>
            String(item.id) === String(product.id)
              ? { ...item, quantity: Math.min(currentStock, newQuantity), price }
              : item
          );
        } else {
          if (requestedQuantity > currentStock) {
            queueNotification({ type: 'warning', message: `Only ${currentStock} items available in stock.` });
            return [...items, { ...product, quantity: currentStock, price }];
          }
          return [...items, { ...product, quantity: requestedQuantity, price }];
        }
      });
      if (success) {
        queueNotification({ type: 'success', message: 'Item added to cart.' });
      }
      return success;
    } catch (err) {
      queueNotification({ type: 'error', message: 'Error checking stock. Please try again.' });
      return false;
    }
  }

  // Update quantity of a cart item
  async function updateQuantity(productId: string | number, newQuantity: number) {
    if (newQuantity < 1) {
      queueNotification({ type: 'error', message: 'Quantity must be at least 1.' });
      return false;
    }
    try {
      const currentStock = await getStock(String(productId), 'shop');
      if (currentStock <= 0) {
        queueNotification({ type: 'error', message: 'This item is out of stock.' });
        return false;
      }
      if (newQuantity > currentStock) {
        queueNotification({ type: 'warning', message: `Only ${currentStock} items available in stock.` });
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
    } catch (err) {
      queueNotification({ type: 'error', message: 'Error updating quantity. Please try again.' });
      return false;
    }
  }

  // Remove item from cart
  function removeItem(productId: string | number) {
    update(items => items.filter(item => String(item.id) !== String(productId)));
  }

  // Clear the cart
  function clearCart() {
    set([]);
    cartNotification.set(null);
    saveCartToStorage([]);
  }

  // Function to reprice all cart items when selected user or custom prices change
  function repriceCartItems() {
    let userId = null;
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('selectedPosUser');
      if (stored) {
        try {
          const user = JSON.parse(stored);
          userId = user?.id;
        } catch {}
      }
    }
    update((items: CartItem[]) => items.map((item: CartItem) => ({
      ...item,
      price: getEffectivePrice(item, userId, item.quantity)
    })));
  }

  // Subscribe to changes in customPrices and selectedPosUser to reprice cart items
  customPrices.subscribe(() => repriceCartItems());
  selectedPosUser.subscribe(() => repriceCartItems());

  return {
    subscribe,
    set,
    update,
    addItem,
    updateQuantity,
    removeItem,
    clearCart
  };
}

export const cartStore = createCartStore();
export const cartTotal = derived(cartStore, $cartStore => $cartStore.reduce((total, item) => total + item.price * item.quantity, 0));
export const cartItemCount = derived(cartStore, $cartStore => $cartStore.reduce((count, item) => count + item.quantity, 0));

// Create a store to check if current user is POS or admin
export const isPosOrAdmin = writableStore<boolean>(false);

// Update isPosOrAdmin when selectedPosUser changes or when user is admin
export async function updateIsPosOrAdmin() {
  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    // Query the profiles table for admin/role
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin, role')
      .eq('auth_user_id', user.id)
      .maybeSingle();
    const isAdmin = !!profile?.is_admin;
    isPosOrAdmin.set(isAdmin || profile?.role === 'pos');
  } else {
    isPosOrAdmin.set(false);
  }
}

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
export function getEffectivePrice(product: Product, userId?: string, quantity: number = 1): number {
  const prices = get(customPrices);
  if (userId && prices[product.id]) return prices[product.id];
  if (product.bulk_prices && Array.isArray(product.bulk_prices) && product.bulk_prices.length > 0) {
    // Sort tiers descending by min_qty, find the best match
    const sorted = [...product.bulk_prices].sort((a, b) => b.min_qty - a.min_qty);
    const tier = sorted.find(t => quantity >= t.min_qty);
    if (tier) return tier.price;
  }
  return product.price;
}

export function getTotal(items: CartItem[]) {
  return items.reduce((total, item) => total + item.price * item.quantity, 0);
}
export function getItemCount(items: CartItem[]) {
  return items.reduce((count, item) => count + item.quantity, 0);
}

// ...return and other methods...
