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
  order_number: string;
  total: number;
  status: OrderStatus;
  created_at: string;
  updated_at: string;
  user_id?: string;
  guest_info?: GuestInfo;
  order_items?: OrderItem[];
  user?: {
    email: string;
    user_metadata?: {
      name?: string;
      phone?: string;
      address?: string;
    };
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