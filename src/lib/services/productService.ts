import { supabase } from '$lib/supabase';
import type { Product } from '$lib/types/index';
import type { PostgrestSingleResponse, PostgrestResponse } from '@supabase/supabase-js';

// Retry utility for async functions
async function retry<T>(fn: () => Promise<T>, retries = 2, delay = 500): Promise<T> {
  let lastErr;
  for (let i = 0; i <= retries; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (i < retries) await new Promise(res => setTimeout(res, delay));
    }
  }
  throw lastErr;
}

// Simple in-memory cache with automatic cleanup
const productCache = new Map<string, { data: Product; timestamp: number }>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

function isExpired(timestamp: number): boolean {
  return Date.now() - timestamp > CACHE_TTL;
}

function cleanExpiredCache() {
  for (const [key, value] of productCache.entries()) {
    if (isExpired(value.timestamp)) {
      productCache.delete(key);
    }
  }
}

export function clearAllProductCache() {
  productCache.clear();
  if (typeof window !== 'undefined') {
    localStorage.removeItem('cached_products');
    localStorage.removeItem('productCache');
  }
}

export async function getProduct(id: string): Promise<Product | null> {
  cleanExpiredCache();
  
  const cached = productCache.get(id);
  if (cached && !isExpired(cached.timestamp)) {
    return cached.data;
  }

  try {
    const { data, error }: PostgrestSingleResponse<Product> = await retry(async () => {
      return await supabase
        .from('products')
        .select('*')
        .eq('id', id)
        .single();
    });
    
    if (error) {
      console.error('Error fetching product:', error);
      return null;
    }
    
    if (data) {
      productCache.set(id, { data, timestamp: Date.now() });
    }
    
    return data;
  } catch (err) {
    console.error('Error fetching product (retry):', err);
    return null;
  }
}

export async function getProducts(category?: string): Promise<Product[]> {
  cleanExpiredCache();
  
  let query = supabase
    .from('products')
    .select('*')
    .order('created_at', { ascending: false });
    
  if (category) {
    query = query.eq('category', category);
  }

  try {
    const { data, error }: PostgrestResponse<Product> = await retry(async () => {
      return await query;
    });
    
    if (error) {
      console.error('Error fetching products:', error);
      return [];
    }
    
    // Cache all fetched products
    (data ?? []).forEach((product: Product) => {
      productCache.set(String(product.id), { data: product, timestamp: Date.now() });
    });
    
    return data || [];
  } catch (err) {
    console.error('Error fetching products (retry):', err);
    return [];
  }
}

export async function updateProductQuantity(id: string, quantity: number): Promise<boolean> {
  const { error } = await supabase
    .from('products')
    .update({ quantity })
    .eq('id', id);

  if (error) {
    console.error('Error updating product quantity:', error);
    return false;
  }

  // Invalidate cache for this product
  productCache.delete(id);
  return true;
}

export async function fetchProducts(category?: string): Promise<{ products: Product[], error: string | null }> {
  try {
    // Always fetch fresh data for admin operations
    clearAllProductCache();
    
    let query = supabase
      .from('products')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (category) {
      query = query.eq('category', category);
    }
    
    const { data, error } = await query;
    
    if (error) {
      console.error('Error fetching products:', error);
      return { products: [], error: error.message };
    }
    
    const products = (data || []).map((product: Product) => ({
      ...product,
      category: product.category || 'flower'
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

// Simplified product loading without redundant caching
export async function loadAllProducts(): Promise<{ products: Product[]; error: string | null }> {
  try {
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .order('created_at', { ascending: false });
      
    if (error) {
      console.error('Error fetching products:', error);
      return { products: [], error: error.message };
    }
    
    return { products: data || [], error: null };
  } catch (err) {
    console.error('Unexpected error fetching products:', err);
    return { products: [], error: 'Failed to fetch products. Please try again later.' };
  }
}

export async function fetchProductsLazy(
  category: string,
  page: number = 1,
  pageSize: number = 4  // Default to tablet view (4 products)
): Promise<{ products: Product[], hasMore: boolean, error: string | null }> {
  try {
    // Calculate the range for pagination
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;

    // First, get the total count for this category
    const { count, error: countError } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true })
      .eq('category', category);

    if (countError) {
      console.error('Error getting product count:', countError);
      return { products: [], hasMore: false, error: countError.message };
    }

    // Then fetch the paginated results
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('category', category)
      .order('created_at', { ascending: false })
      .range(from, to);
    
    if (error) {
      console.error('Error fetching products:', error);
      return { products: [], hasMore: false, error: error.message };
    }
    
    const products = data.map((product: Product) => ({
      ...product,
      category: product.category || 'flower'
    }));
    
    // Calculate if there are more products to load
    const hasMore = count ? from + pageSize < count : false;
    
    console.log('Fetched products:', {
      page,
      pageSize,
      from,
      to,
      count,
      hasMore,
      productsCount: products.length,
      totalProducts: count
    });
    
    return { products, hasMore, error: null };
  } catch (err) {
    console.error('Unexpected error fetching products:', err);
    return { 
      products: [], 
      hasMore: false,
      error: 'Failed to fetch products. Please try again later.' 
    };
  }
}

 