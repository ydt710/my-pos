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
  import type { Product } from '$lib/types';
  import { get } from 'svelte/store';
  import { selectedPosUser } from '$lib/stores/cartStore';

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

  let posPendingTransfers: StockMovement[] = [];

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
    locations = locData;
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

    // Determine user's shop ID based on selectedPosUser store or fallback
    const posUser = get(selectedPosUser);
    if (posUser && typeof posUser === 'object' && 'shop_id' in posUser && typeof posUser.shop_id === 'string') {
      userShopId = posUser.shop_id;
    } else {
      // Fallback: get the first shop location with name 'shop' if locations are loaded
      if (locations.length > 0) {
      const shop = locations.find(l => l.name === 'shop');
         userShopId = shop?.id || null;
      }
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
    await addProduction(selectedProduct, productionQty, note);
    // await fetchData(); // Removed: Realtime will update
    productionQty = 0; note = '';
  }

  async function handleTransferToShop() {
    if (!selectedProduct || transferQty <= 0) return;
    await transferToShop(selectedProduct, transferQty, note);
    // await fetchData(); // Removed: Realtime will update
    transferQty = 0; note = '';
  }

  async function handleAdjustStock() {
    if (!selectedProduct || !adjustmentLocation || adjustmentQty < 0) return;
    await adjustStock(selectedProduct, adjustmentLocation, adjustmentQty, note);
    // await fetchData(); // Removed: Realtime will update
    adjustmentQty = 0; note = '';
  }

  async function handleConfirmProductionDone(id: string | number) {
    await confirmProductionDone(id);
    // await fetchData(); // Removed: Realtime will update
  }

  function getStockLevel(productId: string | number, locationId: string | number): number {
    const entry = stockLevels.find((s) => String(s.product_id) === String(productId) && String(s.location_id) === String(locationId));
    return entry ? entry.quantity : 0;
  }

  async function handleAcceptTransfer(transfer: StockMovement) {
    await acceptStockTransfer(transfer.id as string, transfer.quantity);
    // await fetchData(); // Removed: Realtime will update
     // The stock_movements Realtime subscription will handle updating the pending list
  }

  function openRejectModal(transfer: StockMovement) {
    rejectTransferId = transfer.id;
    rejectActualQty = transfer.quantity;
    rejectReason = '';
    showRejectModal = true;
  }

  async function submitReject() {
    if (rejectTransferId != null) {
      await rejectStockTransfer(String(rejectTransferId), rejectActualQty, rejectReason);
      showRejectModal = false;
      // await fetchData(); // Removed: Realtime will update
       // The stock_movements Realtime subscription will handle updating the pending list
    }
  }
</script>

<svelte:head>
  <title>Admin Stock Management</title>
</svelte:head>

<div class="admin-stock-management">
  <h1>Stock Management</h1>

  {#if error}
    <div class="error">{error}</div>
  {/if}
  {#if loading}
    <div>Loading...</div>
  {:else}
    {#if isAdmin}
      <div class="stock-forms">
        <div class="form-section">
          <h2>Add Production to Facility</h2>
          <div class="field-group">
            <label for="prod-product">Product</label>
            <select id="prod-product" bind:value={selectedProduct}>
              <option value="">Select Product</option>
              {#each products as p}
                <option value={p.id}>{p.name}</option>
              {/each}
            </select>
          </div>
          <div class="field-group">
            <label for="prod-qty">Quantity</label>
            <input id="prod-qty" type="number" min="1" bind:value={productionQty} placeholder="Quantity" />
          </div>
          <div class="field-group">
            <label for="prod-note">Note</label>
            <input id="prod-note" type="text" bind:value={note} placeholder="Note (optional)" />
          </div>
          <button on:click={handleAddProduction}>Add Production</button>
        </div>
        <div class="form-section">
          <h2>Transfer Facility → Shop</h2>
          <div class="field-group">
            <label for="trans-product">Product</label>
            <select id="trans-product" bind:value={selectedProduct}>
              <option value="">Select Product</option>
              {#each products as p}
                <option value={p.id}>{p.name}</option>
              {/each}
            </select>
          </div>
          <div class="field-group">
            <label for="trans-qty">Quantity</label>
            <input id="trans-qty" type="number" min="1" bind:value={transferQty} placeholder="Quantity" />
          </div>
          <div class="field-group">
            <label for="trans-note">Note</label>
            <input id="trans-note" type="text" bind:value={note} placeholder="Note (optional)" />
          </div>
          <button on:click={handleTransferToShop}>Transfer</button>
        </div>
        <div class="form-section">
          <h2>Stocktake / Adjustment</h2>
          <div class="field-group">
            <label for="adj-product">Product</label>
            <select id="adj-product" bind:value={selectedProduct}>
              <option value="">Select Product</option>
              {#each products as p}
                <option value={p.id}>{p.name}</option>
              {/each}
            </select>
          </div>
          <div class="field-group">
            <label for="adj-location">Location</label>
            <select id="adj-location" bind:value={adjustmentLocation}>
              <option value="">Select Location</option>
              {#each locations as l}
                <option value={l.name}>{l.name}</option>
              {/each}
            </select>
          </div>
          <div class="field-group">
            <label for="adj-qty">New Quantity</label>
            <input id="adj-qty" type="number" min="0" bind:value={adjustmentQty} placeholder="New Quantity" />
          </div>
          <div class="field-group">
            <label for="adj-note">Note</label>
            <input id="adj-note" type="text" bind:value={note} placeholder="Note (optional)" />
          </div>
          <button on:click={handleAdjustStock}>Adjust</button>
        </div>
      </div>
      <h2>Current Stock Levels</h2>
      <div class="table-responsive">
        <table>
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
              <tr>
                <td>{p.name}</td>
                {#each locations as l}
                  <td>{getStockLevel(p.id, l.id)}</td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <h2>Pending Productions</h2>
      <div class="table-responsive">
        <table>
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
            {#each stockMovements.filter(m => m.type === 'production' && m.status === 'pending') as m}
              <tr>
                <td>{new Date(m.created_at).toLocaleString()}</td>
                <td>{products.find(p => p.id === m.product_id)?.name || m.product_id}</td>
                <td>{m.quantity}</td>
                <td>{m.note}</td>
                <td><button on:click={() => handleConfirmProductionDone(m.id)}>Confirm Done</button></td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <h2>Recent Stock Movements</h2>
      <div class="table-responsive">
        <table>
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
              <tr>
                <td>{new Date(m.created_at).toLocaleString()}</td>
                <td>{products.find(p => p.id === m.product_id)?.name || m.product_id}</td>
                <td>{m.type}</td>
                <td>{locations.find(l => l.id === m.from_location_id)?.name || '-'}</td>
                <td>{locations.find(l => l.id === m.to_location_id)?.name || '-'}</td>
                <td>{m.quantity}</td>
                <td>{m.note}</td>
                <td>{m.status || 'done'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <h2>Recent Stock Discrepancies</h2>
      <div class="table-responsive">
        <table>
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
              <tr>
                <td>{new Date(d.created_at).toLocaleString()}</td>
                <td>{products.find(p => p.id === d.product_id)?.name || d.product_id}</td>
                <td>{d.expected_quantity}</td>
                <td>{d.actual_quantity}</td>
                <td>{(d.expected_quantity ?? 0) - (d.actual_quantity ?? 0)}</td>
                <td>{d.reason}</td>
                <td>{d.reported_by && profiles[d.reported_by] ? (profiles[d.reported_by].display_name || profiles[d.reported_by].email) : 'Unknown'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <!-- Add Pending Transfers to Your Shop table for admins -->
      <h2>Pending Transfers to Your Shop</h2>
      <div class="table-responsive">
        <table>
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
            <tr>
              <td>{new Date(t.created_at).toLocaleString()}</td>
              <td>{products.find(p => p.id === t.product_id)?.name || t.product_id}</td>
              <td>{t.quantity}</td>
              <td>{t.note}</td>
              <td>
                <button on:click={() => handleAcceptTransfer(t)}>Accept</button>
                <button on:click={() => openRejectModal(t)} style="margin-left:0.5rem;background:#dc3545;">Reject</button>
              </td>
            </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {:else}
      <div class="pos-pending-transfers">
        {#if isAdmin || isActualPosUser}
          {#if isAdmin}
            <pre>stockMovements: {JSON.stringify(stockMovements, null, 2)}</pre>
            <pre>posPendingTransfers: {JSON.stringify(posPendingTransfers, null, 2)}</pre>
          {/if}
          <h2>Pending Transfers to Your Shop</h2>
          <div class="table-responsive">
            <table>
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
                <tr>
                  <td>{new Date(t.created_at).toLocaleString()}</td>
                  <td>{products.find(p => p.id === t.product_id)?.name || t.product_id}</td>
                  <td>{t.quantity}</td>
                  <td>{t.note}</td>
                  <td>
                    <button on:click={() => handleAcceptTransfer(t)}>Accept</button>
                    <button on:click={() => openRejectModal(t)} style="margin-left:0.5rem;background:#dc3545;">Reject</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        {#if showRejectModal}
          <div class="modal-backdrop"></div>
          <div class="modal">
            <h3>Reject Transfer</h3>
            <div class="form-group">
              <label for="reject-actual-qty">Actual Quantity Received</label>
              <input id="reject-actual-qty" type="number" min="0" bind:value={rejectActualQty} />
            </div>
            <div class="form-group">
              <label for="reject-reason">Reason for Rejection</label>
              <input id="reject-reason" type="text" bind:value={rejectReason} />
            </div>
            <div class="modal-actions">
              <button on:click={submitReject} style="background:#dc3545;">Submit</button>
              <button on:click={() => showRejectModal = false}>Cancel</button>
            </div>
          </div>
        {/if}
        {/if}
      </div>
    {/if}
  {/if}
  {#if showRejectModal}
    <div class="modal-backdrop"></div>
    <div class="modal">
      <h3>Reject Transfer</h3>
      <div class="form-group">
        <label for="reject-actual-qty">Actual Quantity Received</label>
        <input id="reject-actual-qty" type="number" min="0" bind:value={rejectActualQty} />
      </div>
      <div class="form-group">
        <label for="reject-reason">Reason for Rejection</label>
        <input id="reject-reason" type="text" bind:value={rejectReason} />
      </div>
      <div class="modal-actions">
        <button on:click={submitReject} style="background:#dc3545;">Submit</button>
        <button on:click={() => showRejectModal = false}>Cancel</button>
      </div>
    </div>
  {/if}
</div>

<style>
  .admin-stock-management {
    max-width: 900px;
    margin: 2rem auto;
    padding: 1rem;
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  }
  h1, h2 { color: #333; }
  .stock-forms {
    display: flex;
    gap: 2rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
  }
  .form-section {
    flex: 1 1 250px;
    background: #f8f9fa;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
    min-width: 250px;
  }
  .field-group {
    display: flex;
    flex-direction: column;
    margin-bottom: 0.75rem;
  }
  .field-group label {
    font-size: 0.95rem;
    margin-bottom: 0.25rem;
    color: #555;
    font-weight: 500;
  }
  input, select {
    padding: 0.5rem;
    border-radius: 4px;
    border: 1px solid #ddd;
    font-size: 1rem;
    max-width: 300px;
    width: 100%;
    box-sizing: border-box;
  }
  button {
    background: #28a745;
    color: #fff;
    border: none;
    cursor: pointer;
    font-weight: bold;
    transition: background 0.2s;
    padding: 0.6rem 1.2rem;
    border-radius: 4px;
    margin-top: 0.5rem;
    font-size: 1rem;
    width: auto;
    align-self: flex-start;
  }
  button:hover { background: #218838; }
  table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 2rem;
  }
  th, td {
    border: 1px solid #eee;
    padding: 0.5rem;
    text-align: left;
  }
  th { background: #f1f1f1; }
  .error { color: #dc3545; margin-bottom: 1rem; }
  .modal-backdrop {
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.4);
    z-index: 1000;
  }
  .modal {
    position: fixed;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    background: #fff;
    padding: 2rem;
    border-radius: 8px;
    z-index: 1010;
    min-width: 300px;
    box-shadow: 0 2px 16px rgba(0,0,0,0.2);
  }
  @media (max-width: 900px) {
    .stock-forms {
      flex-direction: column;
      gap: 1rem;
    }
    .form-section {
      min-width: 0;
      width: 100%;
      padding: 0.5rem;
    }
    .admin-stock-management {
      padding: 0.5rem;
    }
    .table-responsive {
      width: 100%;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
      margin-bottom: 1rem;
    }
    table {
      min-width: 600px;
      font-size: 0.95rem;
    }
    th, td {
      padding: 0.4rem;
    }
    button {
      width: 100%;
      font-size: 1rem;
      padding: 0.5rem 0.75rem;
    }
  }
</style> 

