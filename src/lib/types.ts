export interface Product {
  id: number;
  name: string;
  price: number;
  image_url: string;
  category: string;
  is_special?: boolean;
  is_new?: boolean;
}

export interface CartItem extends Product {
  quantity: number;
}

export interface Order {
  id: number;
  total: number;
  created_at: string;
  order_items: OrderItem[];
}

export interface OrderItem {
  id: number;
  order_id: number;
  product_id: number;
  quantity: number;
  price: number;
  product: {
    name: string;
    price: number;
    image_url: string;
  };
} 