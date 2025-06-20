import { supabase } from '$lib/supabase';
import type { Review } from '$lib/types/reviews';

export async function getProductReviews(productId: string): Promise<Review[]> {
  const { data, error } = await supabase
    .from('reviews')
    .select('*')
    .eq('product_id', productId)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching reviews:', error);
    return [];
  }

  // Get user data for each review
  const reviewsWithUsers = await Promise.all(
    (data || []).map(async (review) => {
      const { data: profileData } = await supabase
        .from('profiles')
        .select('email, display_name')
        .eq('id', review.user_id)
        .single();

      return {
        ...review,
        user: profileData ? {
          email: profileData.email,
          full_name: profileData.display_name
        } : undefined
      };
    })
  );

  return reviewsWithUsers;
}

export async function addReview(review: Omit<Review, 'id' | 'created_at' | 'user'>): Promise<Review | null> {
  const { data, error } = await supabase
    .from('reviews')
    .insert(review)
    .select()
    .single();

  if (error) {
    console.error('Error adding review:', error);
    return null;
  }

  return data;
}

export async function updateProductRating(productId: string): Promise<void> {
  const { data: reviews, error } = await supabase
    .from('reviews')
    .select('rating')
    .eq('product_id', productId);

  if (error) {
    console.error('Error updating product rating:', error);
    return;
  }

  let averageRating = null;
  let reviewCount = 0;
  if (reviews && reviews.length > 0) {
    averageRating = reviews.reduce((acc, review) => acc + review.rating, 0) / reviews.length;
    reviewCount = reviews.length;
  }

  const { error: updateError } = await supabase
    .from('products')
    .update({
      average_rating: averageRating !== null ? Number(averageRating.toFixed(1)) : null,
      review_count: reviewCount
    })
    .eq('id', productId);

  if (updateError) {
    console.error('Error updating product row with new rating/count:', updateError);
  }
}

export async function updateReview(reviewId: string, review: { rating: number; comment: string }): Promise<Review | null> {
  const { data, error } = await supabase
    .from('reviews')
    .update(review)
    .eq('id', reviewId)
    .select()
    .single();

  if (error) {
    console.error('Error updating review:', error);
    return null;
  }

  return data;
} 