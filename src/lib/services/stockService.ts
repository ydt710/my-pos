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

// Add production to facility
export async function addProduction(productId: string, quantity: number, note?: string) {
  const facilityId = await getLocationId('facility');
  if (!facilityId) throw new Error('Facility location not found');
  // Update stock_levels
  await supabase.rpc('increment_product_quantity', {
    product_id: productId,
    amount: quantity
  });
  // Insert stock_movement
  await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: null,
    to_location_id: facilityId,
    quantity,
    type: 'production',
    note
  });
}

// Transfer stock from facility to shop
export async function transferToShop(productId: string, quantity: number, note?: string) {
  const facilityId = await getLocationId('facility');
  const shopId = await getLocationId('shop');
  if (!facilityId || !shopId) throw new Error('Location not found');
  // Decrement facility
  await supabase.rpc('increment_product_quantity', {
    product_id: productId,
    amount: -quantity
  });
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
    .upsert({ product_id: productId, location_id: shopId, quantity: newShopQty }, { onConflict: ['product_id', 'location_id'] });
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
    .upsert({ product_id: productId, location_id: locationId, quantity: newQuantity }, { onConflict: ['product_id', 'location_id'] });
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