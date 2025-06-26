import type { Review } from './reviews';

export interface Product {
  id: string;
  name: string;
  description?: string;
  price: number;
  image_url: string;
  category: string;
  thc_max?: number;
  cbd_max?: number;
  indica?: number;  // 0-100, represents indica percentage. Sativa percentage is (100 - indica)
  is_special?: boolean;
  is_new?: boolean;
  is_out_of_stock?: boolean;  // Manual flag to mark product as out of stock
  special_price?: number;
  low_stock_buffer?: number;  // Minimum stock level before showing low stock notifications
  reviews?: Review[];
  average_rating?: number;
  review_count?: number;
  quantity?: number; // Optional: for cart and cartStore logic
  bulk_prices?: { min_qty: number; price: number }[];
}

export interface CartItem extends Product {
  quantity: number; // This is the quantity in the cart, not stock
}

export type OrderStatus = 'pending' | 'processing' | 'completed' | 'cancelled';

export interface GuestInfo {
  email: string;
  name: string;
  phone: string;
  address: string;
}

export interface OrderItem {
  id: string;
  order_id: string;
  product_id: string;
  quantity: number;
  price: number;
  created_at: string;
  product?: {
    name: string;
    image_url: string;
  };
}

export interface Order {
  id: string;
  total: number;
  status: OrderStatus;
  created_at: string;
  updated_at: string;
  user_id?: string;
  guest_info?: GuestInfo;
  order_items?: OrderItem[];
  user?: {
    email: string;
    display_name?: string;
    phone_number?: string;
    address?: string;
  };
}

export interface OrderFilters {
  status?: OrderStatus;
  dateFrom?: string;
  dateTo?: string;
  search?: string;
  sortBy?: 'created_at' | 'total' | 'status';
  sortOrder?: 'asc' | 'desc';
}

export interface User {
  id: string;
  email: string;
  name?: string;
  phone?: string;
  address?: string;
 //alance?: number; // Optional: for POS user balance
}

export * from './orders';
export * from './ledger'; 