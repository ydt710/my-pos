export interface CreditLedgerEntry {
  id: string;
  user_id: string;
  type: 'order' | 'payment' | 'refund' | 'adjustment' | 'credit_used';
  amount: number;
  order_id?: string;
  created_at: string;
  note?: string;
  method?: string;
} 