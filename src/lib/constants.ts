export const BALANCE_COLORS = {
  positive: '#28a745',
  negative: '#dc3545',
  zero: '#666'
};

// Default product images for categories when no image is provided
export const DEFAULT_PRODUCT_IMAGES = {
  flower: 'https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//canaprop%20(1).webp',
  joints: 'https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//bluntplace-min.webp',
  concentrate: 'https://bulkweedinbox.cc/wp-content/uploads/2024/12/Greasy-Pink.jpg',
  edibles: 'https://longislandinterventions.com/wp-content/uploads/2024/12/Edibles-1.jpg',
  headshop: 'https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//bongs.webp'
} as const;

// Function to get default product image for a category
export function getDefaultProductImage(category: string): string {
  return DEFAULT_PRODUCT_IMAGES[category as keyof typeof DEFAULT_PRODUCT_IMAGES] || DEFAULT_PRODUCT_IMAGES.flower;
}

// Function to get product image with fallback to category default
export function getProductImage(imageUrl: string | null | undefined, category: string): string {
  // If no image URL provided or it's a placeholder, use category default
  if (!imageUrl || imageUrl.includes('via.placeholder.com')) {
    return getDefaultProductImage(category);
  }
  return imageUrl;
}

// Category configurations shared between CategoryNav and Landing Page
export const CATEGORY_CONFIG = {
  joints: {
    id: 'joints',
    name: 'Joints',
    icon: 'fa-joint',
    background: 'https://mjbizdaily.com/wp-content/uploads/2024/08/Pre-rolls_-joints-_2_.webp',
    color: '#00f0ff'
  },
  concentrate: {
    id: 'concentrate', 
    name: 'Extracts',
    icon: 'fa-vial',
    background: 'https://bulkweedinbox.cc/wp-content/uploads/2024/12/Greasy-Pink.jpg',
    color: '#ff6a00'
  },
  flower: {
    id: 'flower',
    name: 'Flower', 
    icon: 'fa-cannabis',
    background: 'https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//dagga%20cat.webp',
    color: '#43e97b'
  },
  edibles: {
    id: 'edibles',
    name: 'Edibles', 
    icon: 'fa-cookie',
    background: 'https://longislandinterventions.com/wp-content/uploads/2024/12/Edibles-1.jpg',
    color: '#fcdd43'
  },
  headshop: {
    id: 'headshop',
    name: 'Headshop', 
    icon: 'fa-store',
    background: 'https://wglybohfygczpapjxwwz.supabase.co/storage/v1/object/public/route420//bongs.webp',
    color: '#b993d6'
  }
} as const;

export const CATEGORY_ICONS: Record<string, string> = {
  joints: 'fa-joint',
  concentrate: 'fa-vial',
  flower: 'fa-cannabis',
  edibles: 'fa-cookie',
  headshop: 'fa-store'
};

export const CATEGORY_BACKGROUNDS: Record<string, string> = {
  joints: CATEGORY_CONFIG.joints.background,
  concentrate: CATEGORY_CONFIG.concentrate.background,
  flower: CATEGORY_CONFIG.flower.background,
  edibles: CATEGORY_CONFIG.edibles.background,
  headshop: CATEGORY_CONFIG.headshop.background
}; 