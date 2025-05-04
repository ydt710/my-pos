import { supabase } from '../supabase';
import type { Product } from '../types';

export async function fetchProducts(): Promise<{ products: Product[], error: string | null }> {
  try {
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .order('category', { ascending: true });
    
    if (error) {
      console.error('Error fetching products:', error);
      return { products: [], error: error.message };
    }
    
    const products = data.map((product: Product) => ({
      ...product,
      quantity: 1,
      category: product.category || 'flower' // Ensure category is never null
    }));
    
    return { products, error: null };
  } catch (err) {
    console.error('Unexpected error fetching products:', err);
    return { 
      products: [], 
      error: 'Failed to fetch products. Please try again later.' 
    };
  }
} 