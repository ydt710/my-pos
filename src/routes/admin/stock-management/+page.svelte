<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import {
    getLocationId,
    getStock,
    addProduction,
    transferToShop,
    adjustStock
  } from '$lib/services/stockService';
  import type { Product } from '$lib/types';

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
  };

  let products: Product[] = [];
  let locations: Location[] = [];
  let stockLevels: StockLevel[] = [];
  let stockMovements: StockMovement[] = [];
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
    const { data: stockData, error: stockErr } = await supabase.from('stock_levels').select('*');
    if (stockErr) { error = 'Failed to load stock levels'; loading = false; return; }
    stockLevels = stockData;
    // Fetch recent stock movements
    const { data: moveData, error: moveErr } = await supabase.from('stock_movements').select('*').order('created_at', { ascending: false }).limit(20);
    if (moveErr) { error = 'Failed to load stock movements'; loading = false; return; }
    stockMovements = moveData;
    loading = false;
  }

  onMount(fetchData);

  async function handleAddProduction() {
    if (!selectedProduct || productionQty <= 0) return;
    await addProduction(selectedProduct, productionQty, note);
    await fetchData();
    productionQty = 0; note = '';
  }

  async function handleTransferToShop() {
    if (!selectedProduct || transferQty <= 0) return;
    await transferToShop(selectedProduct, transferQty, note);
    await fetchData();
    transferQty = 0; note = '';
  }

  async function handleAdjustStock() {
    if (!selectedProduct || !adjustmentLocation || adjustmentQty < 0) return;
    await adjustStock(selectedProduct, adjustmentLocation, adjustmentQty, note);
    await fetchData();
    adjustmentQty = 0; note = '';
  }

  function getStockLevel(productId: string | number, locationId: string | number): number {
    const entry = stockLevels.find((s) => String(s.product_id) === String(productId) && String(s.location_id) === String(locationId));
    return entry ? entry.quantity : 0;
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
    <div class="stock-forms">
      <div class="form-section">
        <h2>Add Production to Facility</h2>
        <select bind:value={selectedProduct}>
          <option value="">Select Product</option>
          {#each products as p}
            <option value={p.id}>{p.name}</option>
          {/each}
        </select>
        <input type="number" min="1" bind:value={productionQty} placeholder="Quantity" />
        <input type="text" bind:value={note} placeholder="Note (optional)" />
        <button on:click={handleAddProduction}>Add Production</button>
      </div>
      <div class="form-section">
        <h2>Transfer Facility → Shop</h2>
        <select bind:value={selectedProduct}>
          <option value="">Select Product</option>
          {#each products as p}
            <option value={p.id}>{p.name}</option>
          {/each}
        </select>
        <input type="number" min="1" bind:value={transferQty} placeholder="Quantity" />
        <input type="text" bind:value={note} placeholder="Note (optional)" />
        <button on:click={handleTransferToShop}>Transfer</button>
      </div>
      <div class="form-section">
        <h2>Stocktake / Adjustment</h2>
        <select bind:value={selectedProduct}>
          <option value="">Select Product</option>
          {#each products as p}
            <option value={p.id}>{p.name}</option>
          {/each}
        </select>
        <select bind:value={adjustmentLocation}>
          <option value="">Select Location</option>
          {#each locations as l}
            <option value={l.id}>{l.name}</option>
          {/each}
        </select>
        <input type="number" min="0" bind:value={adjustmentQty} placeholder="New Quantity" />
        <input type="text" bind:value={note} placeholder="Note (optional)" />
        <button on:click={handleAdjustStock}>Adjust</button>
      </div>
    </div>
    <h2>Current Stock Levels</h2>
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
    <h2>Recent Stock Movements</h2>
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
          </tr>
        {/each}
      </tbody>
    </table>
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
  }
  .form-section {
    flex: 1;
    background: #f8f9fa;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
  }
  input, select, button {
    display: block;
    margin: 0.5rem 0;
    padding: 0.5rem;
    width: 100%;
    border-radius: 4px;
    border: 1px solid #ddd;
  }
  button {
    background: #28a745;
    color: #fff;
    border: none;
    cursor: pointer;
    font-weight: bold;
    transition: background 0.2s;
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
</style> 