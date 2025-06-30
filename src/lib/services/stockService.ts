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
  // Try the database function first, if it doesn't exist, use manual approach
  const { error: rpcError } = await supabase.rpc('confirm_production_done', {
    p_movement_id: stockMovementId,
  });

  if (rpcError && rpcError.code === '42883') {
    // Function doesn't exist, handle manually
    console.log('Database function not available, handling production confirmation manually');
    
    // Get the production movement details
    const { data: movement, error: movementError } = await supabase
      .from('stock_movements')
      .select('*')
      .eq('id', stockMovementId)
      .eq('type', 'production')
      .eq('status', 'pending')
      .single();

    if (movementError || !movement) {
      throw new Error('Production movement not found or already completed');
    }

    // Update TO location stock (increase by produced quantity)
    const { data: currentStock } = await supabase
      .from('stock_levels')
      .select('quantity')
      .eq('product_id', movement.product_id)
      .eq('location_id', movement.to_location_id)
      .single();

    if (currentStock) {
      await supabase
        .from('stock_levels')
        .update({ 
          quantity: currentStock.quantity + movement.quantity
        })
        .eq('product_id', movement.product_id)
        .eq('location_id', movement.to_location_id);
    } else {
      await supabase
        .from('stock_levels')
        .insert({
          product_id: movement.product_id,
          location_id: movement.to_location_id,
          quantity: movement.quantity
        });
    }

    // Mark production as completed
    const { error: updateError } = await supabase
      .from('stock_movements')
      .update({ status: 'completed' })
      .eq('id', stockMovementId);

    if (updateError) {
      throw new Error('Failed to mark production as completed');
    }
  } else if (rpcError) {
    console.error('Error confirming production:', rpcError);
    throw new Error('Failed to confirm production.');
  }
}

// Transfer stock from facility to shop
export async function transferToShop(productId: string, quantity: number, note?: string) {
  const facilityId = await getLocationId('facility');
  const shopId = await getLocationId('shop');
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
  
  // Get current stock level
  const { data } = await supabase
    .from('stock_levels')
    .select('quantity')
    .eq('product_id', productId)
    .eq('location_id', locationId)
    .single();
  const oldQuantity = data?.quantity ?? 0;
  
  // Create the stock movement record
  const { error: movementError } = await supabase.from('stock_movements').insert({
    product_id: productId,
    from_location_id: locationId,
    to_location_id: locationId,
    quantity: newQuantity - oldQuantity,
    type: 'adjustment',
    note,
    created_by
  });
  
  if (movementError) {
    throw new Error('Failed to create stock movement record');
  }
  
  // Manually update the stock level since trigger doesn't handle adjustments properly
  const { error: updateError } = await supabase
    .from('stock_levels')
    .update({ quantity: newQuantity })
    .eq('product_id', productId)
    .eq('location_id', locationId);
  
  if (updateError) {
    // If there's no existing record, insert a new one
    const { error: insertError } = await supabase
      .from('stock_levels')
      .insert({
        product_id: productId,
        location_id: locationId,
        quantity: newQuantity
      });
    
    if (insertError) {
      throw new Error('Failed to update stock level');
    }
  }
}

// Decrement shop stock for a sale
export async function sellFromShop(productId: string, quantity: number, note?: string) {
  const shopId = await getLocationId('shop');
  if (!shopId) throw new Error('Shop location not found');
  const created_by = await getCurrentProfileId();
  
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
  // Try the database function first, if it doesn't exist, use manual approach
  const { error: rpcError } = await supabase.rpc('accept_stock_transfer', {
    p_transfer_id: transferId,
    p_actual_quantity: actualQuantity
  });

  if (rpcError && rpcError.code === '42883') {
    // Function doesn't exist, handle manually
    console.log('Database function not available, handling transfer manually');
    
    // Get the transfer details
    const { data: transfer, error: transferError } = await supabase
      .from('stock_movements')
      .select('*')
      .eq('id', transferId)
      .eq('type', 'transfer')
      .eq('status', 'pending')
      .single();

    if (transferError || !transfer) {
      throw new Error('Transfer not found or already processed');
    }

    // Validate actual quantity
    if (actualQuantity < 0) {
      throw new Error('Actual quantity cannot be negative');
    }

    // Update FROM location stock (reduce)
    const { data: fromStock } = await supabase
      .from('stock_levels')
      .select('quantity')
      .eq('product_id', transfer.product_id)
      .eq('location_id', transfer.from_location_id)
      .single();

    if (fromStock) {
      await supabase
        .from('stock_levels')
        .update({ 
          quantity: fromStock.quantity - transfer.quantity
        })
        .eq('product_id', transfer.product_id)
        .eq('location_id', transfer.from_location_id);
    }

    // Update TO location stock (increase with actual received quantity)
    const { data: toStock } = await supabase
      .from('stock_levels')
      .select('quantity')
      .eq('product_id', transfer.product_id)
      .eq('location_id', transfer.to_location_id)
      .single();

    if (toStock) {
      await supabase
        .from('stock_levels')
        .update({ 
          quantity: toStock.quantity + actualQuantity
        })
        .eq('product_id', transfer.product_id)
        .eq('location_id', transfer.to_location_id);
    } else {
      await supabase
        .from('stock_levels')
        .insert({
          product_id: transfer.product_id,
          location_id: transfer.to_location_id,
          quantity: actualQuantity
        });
    }

    // If there's a discrepancy, log it
    if (actualQuantity !== transfer.quantity) {
      await supabase
        .from('stock_discrepancies')
        .insert({
          product_id: transfer.product_id,
          expected_quantity: transfer.quantity,
          actual_quantity: actualQuantity,
          reason: `Transfer quantity discrepancy - expected ${transfer.quantity} but received ${actualQuantity}`,
          reported_by: transfer.created_by,
          transfer_id: transferId,
          created_at: new Date().toISOString()
        });
    }

    // Mark transfer as completed
    const { error: updateError } = await supabase
      .from('stock_movements')
      .update({ status: 'completed' })
      .eq('id', transferId);

    if (updateError) {
      throw new Error('Failed to mark transfer as completed');
    }
  } else if (rpcError) {
    console.error('Error accepting transfer:', rpcError);
    throw new Error('Failed to accept stock transfer.');
  }
}

// POS: Reject a stock transfer (log discrepancy)
export async function rejectStockTransfer(transferId: string, actualQuantity: number, reason: string) {
  // Try the database function first, if it doesn't exist, use manual approach
  const { error: rpcError } = await supabase.rpc('reject_stock_transfer', {
    p_transfer_id: transferId,
    p_actual_quantity: actualQuantity,
    p_reason: reason
  });

  if (rpcError && rpcError.code === '42883') {
    // Function doesn't exist, handle manually
    console.log('Database function not available, handling transfer rejection manually');
    
    // Get the transfer details
    const { data: transfer, error: transferError } = await supabase
      .from('stock_movements')
      .select('*')
      .eq('id', transferId)
      .eq('type', 'transfer')
      .eq('status', 'pending')
      .single();

    if (transferError || !transfer) {
      throw new Error('Transfer not found or already processed');
    }

    // Validate actual quantity
    if (actualQuantity < 0) {
      throw new Error('Actual quantity cannot be negative');
    }

    // Update FROM location stock (reduce by expected quantity)
    const { data: fromStock } = await supabase
      .from('stock_levels')
      .select('quantity')
      .eq('product_id', transfer.product_id)
      .eq('location_id', transfer.from_location_id)
      .single();

    if (fromStock) {
      await supabase
        .from('stock_levels')
        .update({ 
          quantity: fromStock.quantity - transfer.quantity
        })
        .eq('product_id', transfer.product_id)
        .eq('location_id', transfer.from_location_id);
    }

    // Update TO location stock (add actual received quantity if any)
    if (actualQuantity > 0) {
      const { data: toStock } = await supabase
        .from('stock_levels')
        .select('quantity')
        .eq('product_id', transfer.product_id)
        .eq('location_id', transfer.to_location_id)
        .single();

      if (toStock) {
        await supabase
          .from('stock_levels')
          .update({ 
            quantity: toStock.quantity + actualQuantity
          })
          .eq('product_id', transfer.product_id)
          .eq('location_id', transfer.to_location_id);
      } else {
        await supabase
          .from('stock_levels')
          .insert({
            product_id: transfer.product_id,
            location_id: transfer.to_location_id,
            quantity: actualQuantity
          });
      }
    }

    // Log the discrepancy
    await supabase
      .from('stock_discrepancies')
      .insert({
        product_id: transfer.product_id,
        expected_quantity: transfer.quantity,
        actual_quantity: actualQuantity,
        reason: `REJECTED TRANSFER: ${reason || 'No reason provided'}`,
        reported_by: transfer.created_by,
        transfer_id: transferId,
        created_at: new Date().toISOString()
      });

    // Mark transfer as rejected
    const { error: updateError } = await supabase
      .from('stock_movements')
      .update({ status: 'rejected' })
      .eq('id', transferId);

    if (updateError) {
      throw new Error('Failed to mark transfer as rejected');
    }
  } else if (rpcError) {
    console.error('Error rejecting transfer:', rpcError);
    throw new Error(`Failed to reject stock transfer: ${rpcError.message}`);
  }
}

export function getShopLocationId(): string | null {
  return PUBLIC_SHOP_LOCATION_ID || null;
}

// Better version: dynamically get shop location ID
export async function getShopLocationIdDynamic(): Promise<string | null> {
  return await getLocationId('shop');
}

export async function getShopStockLevels(productIds: string[]): Promise<{ [productId: string]: number }> {
  const shopId = await getLocationId('shop');
  if (!shopId || productIds.length === 0) return {};
  const { data, error } = await supabase
    .from('stock_levels')
    .select('product_id, quantity')
    .eq('location_id', shopId)
    .in('product_id', productIds);
  if (error) return {};
  return Object.fromEntries((data ?? []).map(row => [row.product_id, row.quantity]));
} 