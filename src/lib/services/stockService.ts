import { supabase } from '$lib/supabase';

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
export async function getStock(productId: string, locationName: string): Promise<number> {
  const locationId = await getLocationId(locationName);
  if (!locationId) return 0;
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
  // Insert stock_movement as pending (do not update stock_levels yet)
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: null,
    to_location_id: facilityId,
    quantity,
    type: 'production',
    note,
    status: 'pending'
  });
}

// Confirm production is done: update status and increment stock
export async function confirmProductionDone(stockMovementId: string | number) {
  // Get the stock movement
  const { data: movement, error } = await supabase
    .from('stock_movements')
    .select('*')
    .eq('id', stockMovementId)
    .single();
  if (error || !movement) throw new Error('Production movement not found');
  if (movement.status === 'done') return; // Already confirmed

  // Update facility stock_levels for this product
  const facilityId = movement.to_location_id;
  // Get current quantity
  const { data: stockData } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', movement.product_id)
    .eq('location_id', facilityId)
    .single();
  const newQty = (stockData?.quantity ?? 0) + movement.quantity;
  await supabase
    .from('stock_levels')
    .upsert({ product_id: movement.product_id, location_id: facilityId, quantity: newQty }, { onConflict: 'product_id,location_id' });

  // Update movement status
  await supabase
    .from('stock_movements')
    .update({ status: 'done' })
    .eq('id', stockMovementId);
}

// Transfer stock from facility to shop
export async function transferToShop(productId: string, quantity: number, note?: string) {
  const facilityId = await getLocationId('facility');
  const shopId = await getLocationId('shop');
  if (!facilityId || !shopId) throw new Error('Location not found');
  // Decrement facility stock_levels
  const { data: facilityStock } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', facilityId)
    .single();
  const newFacilityQty = (facilityStock?.quantity ?? 0) - quantity;
  await supabase
    .from('stock_levels')
    .upsert({ product_id: productId, location_id: facilityId, quantity: newFacilityQty }, { onConflict: 'product_id,location_id' });
  // Increment shop
  const { data: shopStock } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', shopId)
    .single();
  const newShopQty = (shopStock?.quantity ?? 0) + quantity;
  await supabase
    .from('stock_levels')
    .upsert({ product_id: productId, location_id: shopId, quantity: newShopQty }, { onConflict: 'product_id,location_id' });
  // Insert stock_movement
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: facilityId,
    to_location_id: shopId,
    quantity,
    type: 'transfer',
    note
  });
}

// Adjust stock at a location (stocktake)
export async function adjustStock(productId: string, locationName: string, newQuantity: number, note?: string) {
  const locationId = await getLocationId(locationName);
  if (!locationId) throw new Error('Location not found');
  // Get current quantity
  const { data } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', locationId)
    .single();
  const oldQuantity = data?.quantity ?? 0;
  // Update stock_levels
  await supabase
    .from('stock_levels')
    .upsert({ product_id: productId, location_id: locationId, quantity: newQuantity }, { onConflict: 'product_id,location_id' });
  // Insert stock_movement
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: locationId,
    to_location_id: locationId,
    quantity: newQuantity - oldQuantity,
    type: 'adjustment',
    note
  });
}

// Decrement shop stock for a sale
export async function sellFromShop(productId: string, quantity: number, note?: string) {
  const shopId = await getLocationId('shop');
  if (!shopId) throw new Error('Shop location not found');
  // Decrement shop
  await supabase.rpc('increment_product_quantity', {
    product_id: productId,
    amount: -quantity
  });
  // Insert stock_movement
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: shopId,
    to_location_id: null,
    quantity,
    type: 'sale',
    note
  });
} 