<script lang="ts">
  
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabase';
  import {
    getLocationId,
    getStock,
    addProduction,
    transferToShop,
    adjustStock,
    confirmProductionDone,
    acceptStockTransfer,
    rejectStockTransfer
  } from '$lib/services/stockService';
  import type { Product } from '$lib/types/index';
  import { get } from 'svelte/store';
  import { selectedPosUser } from '$lib/stores/cartStore';
  import { PUBLIC_SHOP_LOCATION_ID } from '$env/static/public';
  import StarryBackground from '$lib/components/StarryBackground.svelte';

  // Define types for locations, stock levels, and movements
  type Location = { id: string | number; name: string };
  type StockLevel = { id: string | number; product_id: string | number; location_id: string | number; quantity: number };
  type StockMovement = {
    id: string | number;
    product_id: string | number;
    from_location_id: string | number | null;
    to_location_id: string | number | null;
    quantity: number;
    type: string;
    note: string | null;
    created_at: string;
    status?: string;
    created_by?: string | null;
  };

  let products: Product[] = [];
  let locations: Location[] = [];
  let stockLevels: StockLevel[] = [];
  let stockMovements: StockMovement[] = [];
  let discrepancies: any[] = [];
  let profiles: { [id: string]: { display_name?: string; email?: string } } = {};
  let loading = true;
  let error = '';

  // Form state
  let selectedProduct = '';
  let selectedLocation = '';
  let productionQty = 0;
  let transferQty = 0;
  let adjustmentQty = 0;
  let adjustmentLocation = '';
  let note = '';

  // Loading states for buttons
  let addingProduction = false;
  let transferring = false;
  let adjusting = false;
  let confirmingProduction: { [key: string]: boolean } = {};
  let acceptingTransfer: { [key: string]: boolean } = {};
  let rejectingTransfer = false;

  let posPendingTransfers: StockMovement[] = [];
  $: pendingProductions = stockMovements.filter(m => m.type === 'production' && m.status === 'pending');

  // Reactive map for efficient lookup and reactivity in the template
  $: stockMap = stockLevels.reduce((acc, level) => {
    const productId = String(level.product_id);
    const locationId = String(level.location_id);
    if (!acc[productId]) {
      acc[productId] = {};
    }
    acc[productId][locationId] = level.quantity;
    return acc;
  }, {} as { [productId: string]: { [locationId: string]: number } });

  let isAdmin = false;
  let userShopId: string | number | null = null;
  let isActualPosUser = false;

  // Re-added variables for reject modal
  let showRejectModal = false;
  let rejectTransferId: string | number | null = null;
  let rejectActualQty = 0;
  let rejectReason = '';

  // Realtime channel variables
  let stockLevelsChannel: any = null;
  let stockMovementsChannel: any = null;

  async function fetchData() {
    loading = true;
    error = '';
    // Fetch products
    const { data: prodData, error: prodErr } = await supabase.from('products').select('*');
    if (prodErr) { error = 'Failed to load products'; loading = false; return; }
    products = prodData;
    // Fetch locations
    const { data: locData, error: locErr } = await supabase.from('stock_locations').select('*');
    if (locErr) { error = 'Failed to load locations'; loading = false; return; }
    locations = sortLocations(locData);
    // Fetch stock levels
    // Removed delay as Realtime will handle updates
    const { data: stockData, error: stockErr } = await supabase.from('stock_levels').select('*');
    if (stockErr) { console.error('Error fetching stock levels:', stockErr); error = 'Failed to load stock levels'; loading = false; return; }
    stockLevels = stockData || [];

    // Fetch recent stock movements
    const { data: moveData, error: moveErr } = await supabase.from('stock_movements').select('*').order('created_at', { ascending: false }).limit(20);
    if (moveErr) { error = 'Failed to load stock movements'; loading = false; return; }
    stockMovements = moveData || [];

    // Fetch recent discrepancies
    const { data: discrepancyData, error: discrepancyErr } = await supabase
      .from('stock_discrepancies')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(20);
    if (discrepancyErr) {
      error = 'Failed to load discrepancies';
      discrepancies = [];
      loading = false;
      return;
    } else {
      discrepancies = discrepancyData || [];
    }

    // Fetch profiles for discrepancies
    if (discrepancies.length > 0) {
      const userIds = [...new Set(discrepancies.map(d => d.reported_by).filter(id => id))];
      if (userIds.length > 0) {
        const { data: profilesData, error: profilesError } = await supabase
          .from('profiles')
          .select('id, display_name, email')
          .in('id', userIds);

        if (profilesError) {
          console.error('Error fetching profiles for discrepancies:', profilesError);
        } else if (profilesData) {
          profiles = profilesData.reduce((acc, profile) => {
            acc[profile.id] = profile;
            return acc;
          }, {} as { [id: string]: { display_name?: string; email?: string } });
        }
      }
    }

    // Determine user's shop ID based on selectedPosUser store or fallback
    const posUser = get(selectedPosUser);
    if (posUser && typeof posUser === 'object' && 'shop_id' in posUser && typeof posUser.shop_id === 'string') {
      userShopId = posUser.shop_id;
    } else {
      userShopId = PUBLIC_SHOP_LOCATION_ID;
    }

    // Check admin status
    const { data: { user } } = await supabase.auth.getUser();
    let profile = null;
    if (user) {
      const result = await supabase
        .from('profiles')
        .select('is_admin, role')
        .eq('auth_user_id', user.id)
        .maybeSingle();
      profile = result.data;
      isAdmin = !!profile?.is_admin;
    }

    // Determine if the user is an actual POS user (can be true even if admin)
    if (isAdmin) {
      isActualPosUser = true;
    } else {
      isActualPosUser = userShopId != null && profile?.role === 'pos';
    }

    // Update pending transfers for actual POS users
    // Show all pending transfers for both admin and POS user, since you only have one shop
    posPendingTransfers = stockMovements.filter(m => m.type === 'transfer' && m.status === 'pending');
    
    loading = false;
  }

  onMount(async () => {
    // Fetch initial data
    await fetchData();

    // Set up Realtime subscription for stock_levels
    stockLevelsChannel = supabase
      .channel('stock_levels_changes')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'stock_levels' },
        (payload) => {
          console.log('Stock level change received:', payload);
          const { eventType, new: newRecord, old: oldRecord } = payload;
          
          // Update local stockLevels array
          if (eventType === 'INSERT') {
            stockLevels = [...stockLevels, newRecord as StockLevel];
          } else if (eventType === 'UPDATE') {
            stockLevels = stockLevels.map(sl => 
              (sl.product_id === newRecord.product_id && sl.location_id === newRecord.location_id) 
                ? newRecord as StockLevel 
                : sl
            );
          } else if (eventType === 'DELETE') {
             // Filter out the deleted record based on primary key (product_id, location_id assumed based on errors)
             stockLevels = stockLevels.filter(sl => 
                 !(sl.product_id === oldRecord.product_id && sl.location_id === oldRecord.location_id)
             );
          }
          // Re-calculate POS pending transfers if necessary (stock movements might change status)
          // This might require subscribing to stock_movements as well, or refining this logic.
          // For now, just updating stockLevels
        }
      )
      .subscribe();

      // Also subscribe to stock_movements for pending transfers update
      stockMovementsChannel = supabase
        .channel('stock_movements_changes')
        .on('postgres_changes',
          { event: '*', schema: 'public', table: 'stock_movements' },
          (payload) => {
            console.log('Stock movement change received:', payload);
            const { eventType, new: newRecord, old: oldRecord } = payload;
            
            // Update local stockMovements array ensuring reactivity
            if (eventType === 'INSERT') {
              // Add new record to the beginning of the array
              stockMovements = [newRecord as StockMovement, ...stockMovements];
            } else if (eventType === 'UPDATE') {
              // Create a new array with the updated record
              stockMovements = stockMovements.map(m => 
                (m.id === newRecord.id) 
                  ? newRecord as StockMovement 
                  : m
              );
            } else if (eventType === 'DELETE') {
               // Create a new array excluding the deleted record
               stockMovements = stockMovements.filter(m => m.id !== oldRecord.id);
            }

             // Re-calculate POS pending transfers as stockMovements updated
             // Always show all pending transfers
             posPendingTransfers = stockMovements.filter(m => m.type === 'transfer' && m.status === 'pending');
          }
        )
        .subscribe();

  });

  onDestroy(() => {
    // Unsubscribe from Realtime channels when component is destroyed
    if (stockLevelsChannel) {
      supabase.removeChannel(stockLevelsChannel);
    }
    if (stockMovementsChannel) {
        supabase.removeChannel(stockMovementsChannel);
    }
  });

  async function handleAddProduction() {
    if (!selectedProduct || productionQty <= 0) return;
    addingProduction = true;
    error = '';
    try {
      await addProduction(selectedProduct, productionQty, note);
      productionQty = 0; note = '';
    } catch (err) {
      if (err instanceof Error) {
        error = err.message;
      } else if (typeof err === 'string') {
        error = err;
      } else {
        error = 'Failed to add production';
      }
    } finally {
      addingProduction = false;
    }
  }

  async function handleTransferToShop() {
    if (!selectedProduct || transferQty <= 0) return;
    transferring = true;
    error = '';
    try {
      await transferToShop(selectedProduct, transferQty, note);
      transferQty = 0; note = '';
    } catch (err) {
      if (err instanceof Error) {
        error = err.message;
      } else if (typeof err === 'string') {
        error = err;
      } else {
        error = 'Failed to transfer stock';
      }
    } finally {
      transferring = false;
    }
  }

  async function handleAdjustStock() {
    if (!selectedProduct || !adjustmentLocation || adjustmentQty < 0) return;
    adjusting = true;
    error = '';
    try {
      await adjustStock(selectedProduct, adjustmentLocation, adjustmentQty, note);
      adjustmentQty = 0; note = '';
    } catch (err) {
      if (err instanceof Error) {
        error = err.message;
      } else if (typeof err === 'string') {
        error = err;
      } else {
        error = 'Failed to adjust stock';
      }
    } finally {
      adjusting = false;
    }
  }

  async function handleConfirmProductionDone(id: string | number) {
    confirmingProduction[id] = true;
    error = '';
    try {
      await confirmProductionDone(id);
    } catch (err) {
      if (err instanceof Error) {
        error = err.message;
      } else if (typeof err === 'string') {
        error = err;
      } else {
        error = 'Failed to confirm production done';
      }
    } finally {
      confirmingProduction[id] = false;
    }
  }

  async function handleAcceptTransfer(transfer: StockMovement) {
    acceptingTransfer[transfer.id] = true;
    error = '';
    try {
      await acceptStockTransfer(transfer.id as string, transfer.quantity);
    } catch (err) {
      if (err instanceof Error) {
        error = err.message;
      } else if (typeof err === 'string') {
        error = err;
      } else {
        error = 'Failed to accept transfer';
      }
    } finally {
      acceptingTransfer[transfer.id] = false;
    }
  }

  function openRejectModal(transfer: StockMovement) {
    rejectTransferId = transfer.id;
    rejectActualQty = transfer.quantity;
    rejectReason = '';
    showRejectModal = true;
  }

  async function submitReject() {
    if (rejectTransferId != null) {
      rejectingTransfer = true;
      error = '';
      try {
        await rejectStockTransfer(String(rejectTransferId), rejectActualQty, rejectReason);
        showRejectModal = false;
      } catch (err) {
        if (err instanceof Error) {
          error = err.message;
        } else if (typeof err === 'string') {
          error = err;
        } else {
          error = 'Failed to reject transfer';
        }
      } finally {
        rejectingTransfer = false;
      }
    }
  }

  // After fetching locations, sort so 'facility' comes first, then 'shop', then others
  function sortLocations(locations: Location[]): Location[] {
    return [...locations].sort((a, b) => {
      if (a.name === 'facility') return -1;
      if (b.name === 'facility') return 1;
      if (a.name === 'shop') return -1;
      if (b.name === 'shop') return 1;
      return a.name.localeCompare(b.name);
    });
  }
</script>

<svelte:head>
  <title>Admin Stock Management</title>
</svelte:head>

<StarryBackground />

<main class="admin-main">
  <div class="admin-container">
    <div class="admin-header">
      <h1 class="neon-text-cyan">Stock Management</h1>
      <button class="btn btn-primary" on:click={fetchData} disabled={loading}>
        {#if loading}
          🔄 Refreshing...
        {:else}
          🔄 Refresh Data
        {/if}
      </button>
    </div>

    {#if error}
      <div class="alert alert-danger">{error}</div>
    {/if}

    {#if loading}
      <div class="text-center">
        <div class="spinner-large"></div>
        <p class="neon-text-cyan mt-2">Loading...</p>
      </div>
    {:else}
      {#if isAdmin || isActualPosUser}
        <div class="admin-grid admin-grid-3">
          {#if isAdmin}
            <div class="glass">
              <div class="card-header">
                <h2 class="neon-text-cyan">Add Production to Facility</h2>
              </div>
              <div class="card-body">
                <div class="form-group">
                  <label for="prod-product" class="form-label">Product</label>
                  <select id="prod-product" bind:value={selectedProduct} class="form-control form-select">
                    <option value="">Select Product</option>
                    {#each products as p}
                      <option value={p.id}>{p.name}</option>
                    {/each}
                  </select>
                </div>
                <div class="form-group">
                  <label for="prod-qty" class="form-label">Quantity</label>
                  <input id="prod-qty" type="number" min="1" bind:value={productionQty} placeholder="Quantity" class="form-control" />
                </div>
                <div class="form-group">
                  <label for="prod-note" class="form-label">Note</label>
                  <input id="prod-note" type="text" bind:value={note} placeholder="Note (optional)" class="form-control" />
                </div>
                <button on:click={handleAddProduction} disabled={addingProduction} class="btn btn-primary w-full">Add Production</button>
              </div>
            </div>
          {/if}

          <div class="glass">
            <div class="card-header">
              <h2 class="neon-text-cyan">Transfer Facility → Shop</h2>
            </div>
            <div class="card-body">
              <div class="form-group">
                <label for="trans-product" class="form-label">Product</label>
                <select id="trans-product" bind:value={selectedProduct} class="form-control form-select">
                  <option value="">Select Product</option>
                  {#each products as p}
                    <option value={p.id}>{p.name}</option>
                  {/each}
                </select>
              </div>
              <div class="form-group">
                <label for="trans-qty" class="form-label">Quantity</label>
                <input id="trans-qty" type="number" min="1" bind:value={transferQty} placeholder="Quantity" class="form-control" />
              </div>
              <div class="form-group">
                <label for="trans-note" class="form-label">Note</label>
                <input id="trans-note" type="text" bind:value={note} placeholder="Note (optional)" class="form-control" />
              </div>
              <button on:click={handleTransferToShop} disabled={transferring} class="btn btn-primary w-full">Transfer</button>
            </div>
          </div>

          {#if isAdmin}
            <div class="glass">
              <div class="card-header">
                <h2 class="neon-text-cyan">Stocktake / Adjustment</h2>
              </div>
              <div class="card-body">
                <div class="form-group">
                  <label for="adj-product" class="form-label">Product</label>
                  <select id="adj-product" bind:value={selectedProduct} class="form-control form-select">
                    <option value="">Select Product</option>
                    {#each products as p}
                      <option value={p.id}>{p.name}</option>
                    {/each}
                  </select>
                </div>
                <div class="form-group">
                  <label for="adj-location" class="form-label">Location</label>
                  <select id="adj-location" bind:value={adjustmentLocation} class="form-control form-select">
                    <option value="">Select Location</option>
                    {#each locations as l}
                      <option value={l.name}>{l.name}</option>
                    {/each}
                  </select>
                </div>
                <div class="form-group">
                  <label for="adj-qty" class="form-label">New Quantity</label>
                  <input id="adj-qty" type="number" min="0" bind:value={adjustmentQty} placeholder="New Quantity" class="form-control" />
                </div>
                <div class="form-group">
                  <label for="adj-note" class="form-label">Note</label>
                  <input id="adj-note" type="text" bind:value={note} placeholder="Note (optional)" class="form-control" />
                </div>
                <button on:click={handleAdjustStock} disabled={adjusting} class="btn btn-primary w-full">Adjust</button>
              </div>
            </div>
          {/if}
        </div>

        <div class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Current Stock Levels</h2>
          </div>
          <div class="card-body">
            <div class="responsive-table">
              <table class="table-dark">
                <thead>
                  <tr>
                    <th>Product</th>
                    {#each locations as l}
                      <th>{l.name}</th>
                    {/each}
                  </tr>
                </thead>
                <tbody>
                  {#each products as p}
                    <tr class="hover-glow">
                      <td class="neon-text-white">{p.name}</td>
                      {#each locations as l}
                        <td class="neon-text-cyan">{stockMap[p.id]?.[l.id] ?? 0}</td>
                      {/each}
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Pending Productions</h2>
          </div>
          <div class="card-body">
            <div class="responsive-table">
              <table class="table-dark">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Product</th>
                    <th>Qty</th>
                    <th>Note</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each pendingProductions as m}
                    <tr class="hover-glow">
                      <td>{new Date(m.created_at).toLocaleString()}</td>
                      <td class="neon-text-white">{products.find(p => p.id === m.product_id)?.name || m.product_id}</td>
                      <td class="neon-text-cyan">{m.quantity}</td>
                      <td>{m.note}</td>
                      <td>
                        <button on:click={() => handleConfirmProductionDone(m.id)} disabled={confirmingProduction[m.id]} class="btn btn-success btn-sm">
                          Confirm Done
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Recent Stock Movements</h2>
          </div>
          <div class="card-body">
            <div class="responsive-table">
              <table class="table-dark">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Product</th>
                    <th>Type</th>
                    <th>From</th>
                    <th>To</th>
                    <th>Qty</th>
                    <th>Note</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {#each stockMovements as m}
                    <tr class="hover-glow">
                      <td>{new Date(m.created_at).toLocaleString()}</td>
                      <td class="neon-text-white">{products.find(p => p.id === m.product_id)?.name || m.product_id}</td>
                      <td><span class="badge badge-info">{m.type}</span></td>
                      <td>{locations.find(l => l.id === m.from_location_id)?.name || '-'}</td>
                      <td>{locations.find(l => l.id === m.to_location_id)?.name || '-'}</td>
                      <td class="neon-text-cyan">{m.quantity}</td>
                      <td>{m.note}</td>
                      <td>
                        <span class="badge {m.status === 'done' ? 'badge-success' : 'badge-warning'}">
                          {m.status || 'done'}
                        </span>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Recent Stock Discrepancies</h2>
          </div>
          <div class="card-body">
            <div class="responsive-table">
              <table class="table-dark">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Product</th>
                    <th>Expected Qty</th>
                    <th>Actual Qty</th>
                    <th>Loss</th>
                    <th>Reason</th>
                    <th>By</th>
                  </tr>
                </thead>
                <tbody>
                  {#each discrepancies as d}
                    <tr class="hover-glow">
                      <td>{new Date(d.created_at).toLocaleString()}</td>
                      <td class="neon-text-white">{products.find(p => p.id === d.product_id)?.name || d.product_id}</td>
                      <td class="neon-text-cyan">{d.expected_quantity}</td>
                      <td class="neon-text-cyan">{d.actual_quantity}</td>
                      <td class="text-red-400">{(d.expected_quantity ?? 0) - (d.actual_quantity ?? 0)}</td>
                      <td>{d.reason}</td>
                      <td>{d.reported_by && profiles[d.reported_by] ? (profiles[d.reported_by].display_name || profiles[d.reported_by].email) : 'Unknown'}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Pending Transfers to Your Shop</h2>
          </div>
          <div class="card-body">
            <div class="responsive-table">
              <table class="table-dark">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Product</th>
                    <th>Qty</th>
                    <th>Note</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {#each posPendingTransfers as t}
                    <tr class="hover-glow">
                      <td>{new Date(t.created_at).toLocaleString()}</td>
                      <td class="neon-text-white">{products.find(p => p.id === t.product_id)?.name || t.product_id}</td>
                      <td class="neon-text-cyan">{t.quantity}</td>
                      <td>{t.note}</td>
                      <td>
                        <div class="flex gap-1">
                          <button on:click={() => handleAcceptTransfer(t)} disabled={acceptingTransfer[t.id]} class="btn btn-success btn-sm">Accept</button>
                          <button on:click={() => openRejectModal(t)} disabled={rejectingTransfer} class="btn btn-danger btn-sm">Reject</button>
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      {/if}
    {/if}

    {#if showRejectModal}
      <div class="modal-backdrop"></div>
      <div class="modal-content">
        <div class="modal-header">
          <h3 class="neon-text-cyan">Reject Transfer</h3>
          <button class="modal-close" on:click={() => showRejectModal = false}>&times;</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label for="reject-actual-qty" class="form-label">Actual Quantity Received</label>
            <input id="reject-actual-qty" type="number" min="0" bind:value={rejectActualQty} class="form-control" />
          </div>
          <div class="form-group">
            <label for="reject-reason" class="form-label">Reason for Rejection</label>
            <input id="reject-reason" type="text" bind:value={rejectReason} class="form-control" />
          </div>
        </div>
        <div class="modal-actions">
          <button on:click={submitReject} class="btn btn-danger">Submit</button>
          <button on:click={() => showRejectModal = false} class="btn btn-secondary">Cancel</button>
        </div>
      </div>
    {/if}
  </div>
</main>

<style>
  .admin-main {
    min-height: 100vh;
    padding-top: 80px;
    background: transparent;
  }

  .admin-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
  }

  .admin-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
  }

  .admin-header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    letter-spacing: 1px;
  }

  .text-red-400 {
    color: #f87171;
  }

  @media (max-width: 768px) {
    .admin-container {
      padding: 10px;
    }
    
    .admin-header {
      flex-direction: column;
      gap: 1rem;
      align-items: stretch;
    }
    
    .admin-header h1 {
      font-size: 2rem;
    }
  }

  .responsive-table {
    width: 100%;
    overflow-x: auto;
    background: rgba(24,28,40,0.85);
    border-radius: 14px;
    box-shadow: 0 0 24px #00f2fe22;
    border: 1.5px solid #00f2fe44;
    margin-bottom: 2rem;
    
  }

  .responsive-table table {
    min-width: 700px;
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    background: transparent;
  }

  .responsive-table th, .responsive-table td {
    padding: 0.7rem 1rem;
    font-size: 1rem;
    white-space: nowrap;
    border-bottom: 1px solid rgba(0,242,254,0.08);
  }

  .responsive-table th {
    color: #00f2fe;
    font-weight: 700;
    background: rgba(24,28,40,0.92);
    border-bottom: 2px solid #00f2fe44;
  }

  .responsive-table tr:last-child td {
    border-bottom: none;
  }

  @media (max-width: 900px) {
    .responsive-table table {
      min-width: 600px;
    }
    .responsive-table th, .responsive-table td {
      font-size: 0.95rem;
      padding: 0.5rem 0.5rem;
    }
  }
  @media (max-width: 600px) {
    .responsive-table {
      padding: 0.2rem 0.1rem 0.5rem 0.1rem;
      border-radius: 8px;
    }
    .responsive-table table {
      min-width: 520px;
    }
    .responsive-table th, .responsive-table td {
      font-size: 0.89rem;
      padding: 0.35rem 0.3rem;
    }
  }
</style> 

