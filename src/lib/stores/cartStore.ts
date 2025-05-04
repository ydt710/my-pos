import { writable } from 'svelte/store';
import type { CartItem, Product } from '../types';

// Create the cart store
function createCartStore() {
  const { subscribe, set, update } = writable<CartItem[]>([]);

  return {
    subscribe,
    addItem: (product: Product) => {
      if (product.quantity <= 0) return;
      
      update(items => {
        const existing = items.find(item => item.id === product.id);
        if (existing) {
          // Update existing item quantity
          return items.map(item =>
            item.id === product.id
              ? { ...item, quantity: Math.min(99, item.quantity + product.quantity) }
              : item
          );
        } else {
          // Add new item with quantity between 1 and 99
          return [...items, { 
            ...product, 
            quantity: Math.min(99, Math.max(1, product.quantity))
          }];
        }
      });
    },
    updateQuantity: (productId: number, newQuantity: number) => {
      update(items => {
        return items.map(item =>
          item.id === productId
            ? { ...item, quantity: Math.min(99, Math.max(1, newQuantity)) }
            : item
        );
      });
    },
    removeItem: (productId: number) => {
      update(items => items.filter(item => item.id !== productId));
    },
    clearCart: () => set([]),
    getTotal: (items: CartItem[]) => {
      return items.reduce((total, item) => total + item.price * item.quantity, 0);
    },
    getItemCount: (items: CartItem[]) => {
      return items.reduce((count, item) => count + item.quantity, 0);
    }
  };
}

export const cartStore = createCartStore(); 