import { supabase } from '$lib/supabase';
import { PUBLIC_SHOP_LOCATION_ID } from '$env/static/public';

// Helper: Get current user's profile id
async function getCurrentProfileId(): Promise<string | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data: profile } = await supabase
    .from('profiles')
    .select('id')
    .eq('auth_user_id', user.id)
    .maybeSingle();
  return profile?.id ?? null;
}

// Utility: Get location ID by name
export async function getLocationId(name: string): Promise<string | null> {
  const { data, error } = await supabase
    .from('stock_locations')
    .select('id')
    .eq('name', name)
    .single();
  return data?.id ?? null;
}

// Get stock level for a product at a location
export async function getStock(productId: string, locationName: string, opts?: { signal?: AbortSignal }): Promise<number> {
  const locationId = await getLocationId(locationName);
  if (!locationId) return 0;
  // Optionally support abort signal for future fetches
  if (opts?.signal?.aborted) return 0;
  const { data } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', locationId)
    .single();
  return data?.quantity ?? 0;
}

// Add production to facility (now creates a pending production movement)
export async function addProduction(productId: string, quantity: number, note?: string) {
  const facilityId = await getLocationId('facility');
  if (!facilityId) throw new Error('Facility location not found');
  const created_by = await getCurrentProfileId();
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: null,
    to_location_id: facilityId,
    quantity,
    type: 'production',
    note,
    status: 'pending',
    created_by
  });
}

// Confirm production is done: update status and increment stock
export async function confirmProductionDone(stockMovementId: string | number) {
  const { error } = await supabase.rpc('confirm_production_done', {
    p_movement_id: stockMovementId,
  });

  if (error) {
    console.error('Error confirming production:', error);
    throw new Error('Failed to confirm production.');
  }
}

// Transfer stock from facility to shop
export async function transferToShop(productId: string, quantity: number, note?: string) {
  const facilityId = await getLocationId('facility');
  const shopId = getShopLocationId();
  if (!facilityId || !shopId) throw new Error('Location not found');
  const created_by = await getCurrentProfileId();
  const { data: facilityStock } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', facilityId)
    .single();
  const currentFacilityQty = facilityStock?.quantity ?? 0;
  if (currentFacilityQty <= 0) {
    throw new Error('No stock available in facility for this product.');
  }
  if (quantity > currentFacilityQty) {
    throw new Error('Not enough stock in facility to transfer the requested quantity.');
  }
  const newFacilityQty = currentFacilityQty - quantity;
  await supabase
    .from('stock_levels')
    .upsert({ product_id: productId, location_id: facilityId, quantity: newFacilityQty }, { onConflict: 'product_id,location_id' });
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: facilityId,
    to_location_id: shopId,
    quantity,
    type: 'transfer',
    note,
    status: 'pending',
    created_by
  });
}

// Adjust stock at a location (stocktake)
export async function adjustStock(productId: string, locationName: string, newQuantity: number, note?: string) {
  const locationId = await getLocationId(locationName);
  if (!locationId) throw new Error('Location not found');
  const created_by = await getCurrentProfileId();
  const { data } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', locationId)
    .single();
  const oldQuantity = data?.quantity ?? 0;
  await supabase
    .from('stock_levels')
    .upsert({ product_id: productId, location_id: locationId, quantity: newQuantity }, { onConflict: 'product_id,location_id' });
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: locationId,
    to_location_id: locationId,
    quantity: newQuantity - oldQuantity,
    type: 'adjustment',
    note,
    created_by
  });
}

// Decrement shop stock for a sale
export async function sellFromShop(productId: string, quantity: number, note?: string) {
  const shopId = getShopLocationId();
  if (!shopId) throw new Error('Shop location not found');
  const created_by = await getCurrentProfileId();
  await supabase.rpc('increment_product_quantity', {
    product_id: productId,
    amount: -quantity
  });
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: shopId,
    to_location_id: null,
    quantity,
    type: 'sale',
    note,
    created_by
  });
}

// POS: Accept a stock transfer (confirm received quantity)
export async function acceptStockTransfer(transferId: string, actualQuantity: number) {
  const { error } = await supabase.rpc('accept_stock_transfer', {
    p_transfer_id: transferId,
    p_actual_quantity: actualQuantity
  });

  if (error) {
    console.error('Error accepting transfer:', error);
    throw new Error('Failed to accept stock transfer.');
  }
}

// POS: Reject a stock transfer (log discrepancy)
export async function rejectStockTransfer(transferId: string, actualQuantity: number, reason: string) {
  // Get the transfer
  const { data: transfer, error } = await supabase
    .from('stock_movements')
    .select('*')
    .eq('id', transferId)
    .single();
  if (error || !transfer) throw new Error('Transfer not found');
  if (transfer.status === 'done') return;

  // Update shop stock_levels with actual received
  const shopId = transfer.to_location_id;
  const { data: shopStock } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', transfer.product_id)
    .eq('location_id', shopId)
    .single();
  const newShopQty = (shopStock?.quantity ?? 0) + actualQuantity;
  await supabase
    .from('stock_levels')
    .upsert({ product_id: transfer.product_id, location_id: shopId, quantity: newShopQty }, { onConflict: 'product_id,location_id' });

  // Update movement status and quantity
  await supabase
    .from('stock_movements')
    .update({ status: 'rejected', quantity: actualQuantity, note: reason })
    .eq('id', transferId);

  // Log discrepancy with user trackability
  const reported_by = await getCurrentProfileId();
  await supabase.from('stock_discrepancies').insert({
    transfer_id: transferId,
    product_id: transfer.product_id,
    expected_quantity: transfer.quantity,
    actual_quantity: actualQuantity,
    reason,
    reported_by
  });
}

export function getShopLocationId(): string | null {
  return PUBLIC_SHOP_LOCATION_ID || null;
}

export async function getShopStockLevels(productIds: string[]): Promise<{ [productId: string]: number }> {
  const shopId = getShopLocationId();
  if (!shopId || productIds.length === 0) return {};
  const { data, error } = await supabase
    .from('stock_levels')
    .select('product_id, quantity')
    .eq('location_id', shopId)
    .in('product_id', productIds);
  if (error) return {};
  return Object.fromEntries((data ?? []).map(row => [row.product_id, row.quantity]));
} 