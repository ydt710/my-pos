export type TransactionCategory = 
  | 'sale'
  | 'credit_payment'
  | 'cash_payment'
  | 'overpayment_credit'
  | 'cash_change'
  | 'pos_sale'
  | 'online_sale'
  | 'debt_payment'
  | 'cancellation'
  | 'credit_adjustment'
  | 'debit_adjustment'
  | 'balance_adjustment';

export interface Transaction {
  id: string;
  created_at: string;
  user_id: string;
  order_id: string;
  order_number?: string;
  category: TransactionCategory;
  method: string; // 'cash', 'card', 'system', etc.
  cash_amount: number;
  balance_amount: number;
  total_amount: number;
  description?: string;
} 