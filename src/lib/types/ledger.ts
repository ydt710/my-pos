export interface Transaction {
  id: string;
  user_id: string;
  order_id?: string;
  amount: number;
  method?: string;
  type: 'payment' | 'refund' | 'debt' | 'credit';
  created_at: string;
} 