import { supabase } from '$lib/supabase';

export interface StoreSettings {
  store_name: string;
  store_email: string;
  store_phone: string;
  store_address: string;
  currency: string;
  tax_rate: number;
  shipping_fee: number;
  min_order_amount: number;
  free_shipping_threshold: number;
  business_hours: Record<string, string>;
}

let cachedSettings: StoreSettings | null = null;

export async function getStoreSettings(): Promise<StoreSettings> {
  if (cachedSettings) {
    return cachedSettings;
  }

  try {
    const { data, error } = await supabase.rpc('get_store_settings');
    
    if (error) throw error;
    
    cachedSettings = data;
    return data;
  } catch (error) {
    console.error('Error fetching store settings:', error);
    // Return default settings if fetch fails
    return {
      store_name: 'My POS Store',
      store_email: 'store@example.com',
      store_phone: '+27 11 123 4567',
      store_address: '123 Main Street, Johannesburg, 2000',
      currency: 'ZAR',
      tax_rate: 15,
      shipping_fee: 50,
      min_order_amount: 100,
      free_shipping_threshold: 500,
      business_hours: {}
    };
  }
}

export async function calculateTax(subtotal: number): Promise<number> {
  try {
    const { data, error } = await supabase.rpc('calculate_tax_amount', { 
      subtotal_amount: subtotal 
    });
    
    if (error) throw error;
    return data || 0;
  } catch (error) {
    console.error('Error calculating tax:', error);
    return subtotal * 0.15; // Default 15% tax
  }
}

export async function calculateShipping(subtotal: number, isPosOrder: boolean = false): Promise<number> {
  try {
    const { data, error } = await supabase.rpc('calculate_shipping_fee', { 
      subtotal_amount: subtotal,
      is_pos_order: isPosOrder
    });
    
    if (error) throw error;
    return data || 0;
  } catch (error) {
    console.error('Error calculating shipping:', error);
    return isPosOrder ? 0 : 50; // Default shipping for non-POS orders
  }
}

export async function generateInvoiceNumber(): Promise<string> {
  try {
    const { data, error } = await supabase.rpc('generate_invoice_number');
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error generating invoice number:', error);
    // Fallback to timestamp-based number
    return `INV-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`;
  }
}

// Clear cache when settings are updated
export function clearSettingsCache() {
  cachedSettings = null;
}

export function formatCurrency(amount: number, currency: string = 'ZAR'): string {
  const currencySymbols: Record<string, string> = {
    'ZAR': 'R',
    'USD': '$',
    'EUR': '€'
  };
  
  const symbol = currencySymbols[currency] || currency;
  return `${symbol}${amount.toFixed(2)}`;
} 