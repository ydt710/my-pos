<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { fade } from 'svelte/transition';

  interface Settings {
    store_name: string;
    store_email: string;
    store_phone: string;
    store_address: string;
    currency: string;
    tax_rate: number;
    shipping_fee: number;
    min_order_amount: number;
    free_shipping_threshold: number;
    business_hours: {
      monday: string;
      tuesday: string;
      wednesday: string;
      thursday: string;
      friday: string;
      saturday: string;
      sunday: string;
    };
    notification_email: string;
    maintenance_mode: boolean;
  }

  let settings: Settings = {
    store_name: '',
    store_email: '',
    store_phone: '',
    store_address: '',
    currency: 'ZAR',
    tax_rate: 15,
    shipping_fee: 50,
    min_order_amount: 100,
    free_shipping_threshold: 500,
    business_hours: {
      monday: '09:00-17:00',
      tuesday: '09:00-17:00',
      wednesday: '09:00-17:00',
      thursday: '09:00-17:00',
      friday: '09:00-17:00',
      saturday: '09:00-13:00',
      sunday: 'Closed'
    },
    notification_email: '',
    maintenance_mode: false
  };

  let loading = true;
  let saving = false;
  let error: string | null = null;
  let success: string | null = null;

  onMount(() => {
    loadSettings();
  });

  async function loadSettings() {
    loading = true;
    error = null;
    try {
      const { data, error: err } = await supabase
        .from('settings')
        .select('*')
        .single();

      if (err) throw err;
      if (data) {
        settings = { ...settings, ...data };
      }
    } catch (err) {
      console.error('Error loading settings:', err);
      error = 'Failed to load settings';
    } finally {
      loading = false;
    }
  }

  async function saveSettings() {
    saving = true;
    error = null;
    success = null;
    try {
      const { error: err } = await supabase
        .from('settings')
        .upsert(settings);

      if (err) throw err;
      success = 'Settings saved successfully';
    } catch (err) {
      console.error('Error saving settings:', err);
      error = 'Failed to save settings';
    } finally {
      saving = false;
    }
  }

  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
</script>

<div class="settings-page" in:fade>
  <header class="page-header">
    <h1>Settings</h1>
  </header>

  {#if error}
    <div class="alert error" role="alert">{error}</div>
  {/if}

  {#if success}
    <div class="alert success" role="alert">{success}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading settings...</div>
  {:else}
    <form on:submit|preventDefault={saveSettings} class="settings-form">
      <section class="settings-section">
        <h2>Store Information</h2>
        <div class="form-group">
          <label for="store_name">Store Name</label>
          <input 
            type="text" 
            id="store_name" 
            bind:value={settings.store_name}
            required
          />
        </div>

        <div class="form-group">
          <label for="store_email">Store Email</label>
          <input 
            type="email" 
            id="store_email" 
            bind:value={settings.store_email}
            required
          />
        </div>

        <div class="form-group">
          <label for="store_phone">Store Phone</label>
          <input 
            type="tel" 
            id="store_phone" 
            bind:value={settings.store_phone}
            required
          />
        </div>

        <div class="form-group">
          <label for="store_address">Store Address</label>
          <textarea 
            id="store_address" 
            bind:value={settings.store_address}
            rows="3"
            required
          ></textarea>
        </div>
      </section>

      <section class="settings-section">
        <h2>Financial Settings</h2>
        <div class="form-group">
          <label for="currency">Currency</label>
          <select id="currency" bind:value={settings.currency}>
            <option value="ZAR">South African Rand (ZAR)</option>
            <option value="USD">US Dollar (USD)</option>
            <option value="EUR">Euro (EUR)</option>
          </select>
        </div>

        <div class="form-group">
          <label for="tax_rate">Tax Rate (%)</label>
          <input 
            type="number" 
            id="tax_rate" 
            bind:value={settings.tax_rate}
            min="0"
            max="100"
            step="0.1"
            required
          />
        </div>

        <div class="form-group">
          <label for="shipping_fee">Default Shipping Fee</label>
          <input 
            type="number" 
            id="shipping_fee" 
            bind:value={settings.shipping_fee}
            min="0"
            step="0.01"
            required
          />
        </div>

        <div class="form-group">
          <label for="min_order_amount">Minimum Order Amount</label>
          <input 
            type="number" 
            id="min_order_amount" 
            bind:value={settings.min_order_amount}
            min="0"
            step="0.01"
            required
          />
        </div>

        <div class="form-group">
          <label for="free_shipping_threshold">Free Shipping Threshold</label>
          <input 
            type="number" 
            id="free_shipping_threshold" 
            bind:value={settings.free_shipping_threshold}
            min="0"
            step="0.01"
            required
          />
        </div>
      </section>

      <section class="settings-section">
        <h2>Business Hours</h2>
        {#each days as day}
          <div class="form-group">
            <label for={day}>{day.charAt(0).toUpperCase() + day.slice(1)}</label>
            <input 
              type="text" 
              id={day} 
              bind:value={settings.business_hours[day]}
              placeholder="09:00-17:00 or Closed"
              required
            />
          </div>
        {/each}
      </section>

      <section class="settings-section">
        <h2>Notifications</h2>
        <div class="form-group">
          <label for="notification_email">Notification Email</label>
          <input 
            type="email" 
            id="notification_email" 
            bind:value={settings.notification_email}
            required
          />
        </div>
      </section>

      <section class="settings-section">
        <h2>Maintenance</h2>
        <div class="form-group">
          <label class="checkbox-label">
            <input 
              type="checkbox" 
              bind:checked={settings.maintenance_mode}
            />
            Enable Maintenance Mode
          </label>
          <p class="help-text">When enabled, only administrators can access the store.</p>
        </div>
      </section>

      <div class="form-actions">
        <button type="submit" class="save-btn" disabled={saving}>
          {saving ? 'Saving...' : 'Save Settings'}
        </button>
      </div>
    </form>
  {/if}
</div>

<style>
  .settings-page {
    padding: 1rem;
  }

  .page-header {
    margin-bottom: 2rem;
  }

  h1 {
    margin: 0;
    font-size: 2rem;
    color: #333;
  }

  h2 {
    margin: 0 0 1.5rem;
    font-size: 1.5rem;
    color: #444;
  }

  .alert {
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
  }

  .alert.error {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
  }

  .alert.success {
    background: #d4edda;
    color: #155724;
    border: 1px solid #c3e6cb;
  }

  .settings-form {
    max-width: 800px;
    margin: 0 auto;
  }

  .settings-section {
    background: white;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    margin-bottom: 2rem;
  }

  .form-group {
    margin-bottom: 1.5rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    color: #333;
    font-weight: 500;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
  }

  .help-text {
    margin: 0.5rem 0 0;
    font-size: 0.875rem;
    color: #666;
  }

  input[type="text"],
  input[type="email"],
  input[type="tel"],
  input[type="number"],
  select,
  textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 1rem;
  }

  input[type="checkbox"] {
    width: 1.25rem;
    height: 1.25rem;
    margin: 0;
  }

  textarea {
    resize: vertical;
    min-height: 100px;
  }

  input:focus,
  select:focus,
  textarea:focus {
    outline: none;
    border-color: #80bdff;
    box-shadow: 0 0 0 0.2rem rgba(0,123,255,.25);
  }

  .form-actions {
    text-align: center;
    margin-top: 2rem;
  }

  .save-btn {
    background: #28a745;
    color: white;
    border: none;
    padding: 0.75rem 2rem;
    border-radius: 4px;
    font-size: 1.1rem;
    font-weight: 500;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .save-btn:hover:not(:disabled) {
    background: #218838;
  }

  .save-btn:disabled {
    background: #6c757d;
    cursor: not-allowed;
  }

  .loading {
    text-align: center;
    padding: 2rem;
    color: #666;
  }

  @media (max-width: 800px) {
    .settings-section {
      padding: 1.5rem;
    }

    .form-actions {
      position: sticky;
      bottom: 0;
      background: white;
      padding: 1rem;
      margin: 0 -1rem;
      box-shadow: 0 -2px 10px rgba(0,0,0,0.1);
    }

    .save-btn {
      width: 100%;
    }
  }
</style> 