<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { fade } from 'svelte/transition';
  import { clearSettingsCache } from '$lib/services/settingsService';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import { starryBackground } from '$lib/stores/settingsStore';

  interface Settings {
    id: number;
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
      [key: string]: string;
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
    google_maps_embed_url: string;
    facebook_url: string;
    instagram_url: string;
    twitter_url: string;
  }

  let settings: Settings = {
    id: 1,
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
    maintenance_mode: false,
    google_maps_embed_url: '',
    facebook_url: '',
    instagram_url: '',
    twitter_url: ''
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
        .limit(1)
        .maybeSingle();

      if (err) throw err;
      if (data) {
        if (typeof data.business_hours === 'string') {
          try {
            data.business_hours = JSON.parse(data.business_hours);
          } catch (e) {
            console.error('Error parsing business_hours:', e);
          }
        }
        settings = { ...settings, ...data };
      }
    } catch (err) {
      console.error('Error loading settings:', err);
      error = 'Failed to load settings. Make sure the settings table exists and has an id column.';
    } finally {
      loading = false;
    }
  }

  async function saveSettings() {
    saving = true;
    error = null;
    success = null;
    try {
      const dataToSave = {
        ...settings,
        business_hours: JSON.stringify(settings.business_hours)
      };

      const { error: err } = await supabase
        .from('settings')
        .upsert(dataToSave);

      if (err) throw err;
      success = 'Settings saved successfully';
      clearSettingsCache();
    } catch (err) {
      console.error('Error saving settings:', err);
      error = 'Failed to save settings';
    } finally {
      saving = false;
    }
  }

  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
</script>

<StarryBackground />

<main class="admin-main">
  <div class="admin-container">
    <div class="admin-header">
      <h1 class="neon-text-cyan">Settings</h1>
    </div>

    {#if error}
      <div class="alert alert-danger" role="alert">{error}</div>
    {/if}

    {#if success}
      <div class="alert alert-success" role="alert">{success}</div>
    {/if}

    {#if loading}
      <div class="text-center">
        <div class="spinner-large"></div>
        <p class="neon-text-cyan mt-2">Loading settings...</p>
      </div>
    {:else}
      <form on:submit|preventDefault={saveSettings} class="settings-form">
        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Store Information</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-2 gap-3">
              <div class="form-group">
                <label for="store_name" class="form-label">Store Name</label>
                <input 
                  type="text" 
                  id="store_name" 
                  bind:value={settings.store_name}
                  required
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="store_email" class="form-label">Store Email</label>
                <input 
                  type="email" 
                  id="store_email" 
                  bind:value={settings.store_email}
                  required
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="store_phone" class="form-label">Store Phone</label>
                <input 
                  type="tel" 
                  id="store_phone" 
                  bind:value={settings.store_phone}
                  required
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="store_address" class="form-label">Store Address</label>
                <textarea 
                  id="store_address" 
                  bind:value={settings.store_address}
                  rows="3"
                  required
                  class="form-control"
                ></textarea>
              </div>
            </div>
          </div>
        </section>

        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Financial Settings</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-2 gap-3">
              <div class="form-group">
                <label for="currency" class="form-label">Currency</label>
                <select id="currency" bind:value={settings.currency} class="form-control form-select">
                  <option value="ZAR">South African Rand (ZAR)</option>
                  <option value="USD">US Dollar (USD)</option>
                  <option value="EUR">Euro (EUR)</option>
                </select>
              </div>

              <div class="form-group">
                <label for="tax_rate" class="form-label">Tax Rate (%)</label>
                <input 
                  type="number" 
                  id="tax_rate" 
                  bind:value={settings.tax_rate}
                  min="0"
                  max="100"
                  step="0.1"
                  required
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="shipping_fee" class="form-label">Default Shipping Fee</label>
                <input 
                  type="number" 
                  id="shipping_fee" 
                  bind:value={settings.shipping_fee}
                  min="0"
                  step="0.01"
                  required
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="min_order_amount" class="form-label">Minimum Order Amount</label>
                <input 
                  type="number" 
                  id="min_order_amount" 
                  bind:value={settings.min_order_amount}
                  min="0"
                  step="0.01"
                  required
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="free_shipping_threshold" class="form-label">Free Shipping Threshold</label>
                <input 
                  type="number" 
                  id="free_shipping_threshold" 
                  bind:value={settings.free_shipping_threshold}
                  min="0"
                  step="0.01"
                  required
                  class="form-control"
                />
              </div>
            </div>
          </div>
        </section>

        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Business Hours</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-2 gap-3">
              {#each days as day}
                <div class="form-group">
                  <label for={day} class="form-label">{day.charAt(0).toUpperCase() + day.slice(1)}</label>
                  <input 
                    type="text" 
                    id={day} 
                    bind:value={settings.business_hours[day]}
                    placeholder="09:00-17:00 or Closed"
                    required
                    class="form-control"
                  />
                </div>
              {/each}
            </div>
          </div>
        </section>

        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Notifications</h2>
          </div>
          <div class="card-body">
            <div class="form-group">
              <label for="notification_email" class="form-label">Notification Email</label>
              <input 
                type="email" 
                id="notification_email" 
                bind:value={settings.notification_email}
                required
                class="form-control"
              />
            </div>
          </div>
        </section>

        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Google Maps Integration</h2>
          </div>
          <div class="card-body">
            <div class="form-group">
              <label for="google_maps_embed_url" class="form-label">Google Maps Embed URL</label>
              <textarea 
                id="google_maps_embed_url" 
                bind:value={settings.google_maps_embed_url}
                rows="3"
                placeholder="https://www.google.com/maps/embed?pb=..."
                class="form-control"
              ></textarea>
              <p class="help-text">Paste the Google Maps embed URL from Google Maps. Go to Google Maps → Share → Embed a map → Copy HTML → Paste only the src URL part.</p>
            </div>
          </div>
        </section>

        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Social Media Links</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-1 gap-3">
              <div class="form-group">
                <label for="facebook_url" class="form-label">Facebook Page URL</label>
                <input 
                  type="url" 
                  id="facebook_url" 
                  bind:value={settings.facebook_url}
                  placeholder="https://facebook.com/yourpage"
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="instagram_url" class="form-label">Instagram Profile URL</label>
                <input 
                  type="url" 
                  id="instagram_url" 
                  bind:value={settings.instagram_url}
                  placeholder="https://instagram.com/youraccount"
                  class="form-control"
                />
              </div>

              <div class="form-group">
                <label for="twitter_url" class="form-label">Twitter Profile URL</label>
                <input 
                  type="url" 
                  id="twitter_url" 
                  bind:value={settings.twitter_url}
                  placeholder="https://twitter.com/youraccount"
                  class="form-control"
                />
              </div>
            </div>
          </div>
        </section>

        <section class="glass mb-4">
          <div class="card-header">
            <h2 class="neon-text-cyan">Interface Settings</h2>
          </div>
          <div class="card-body">
            <div class="form-group">
              <label class="checkbox-label">
                <input 
                  type="checkbox" 
                  bind:checked={$starryBackground}
                />
                Enable Starry Background
              </label>
              <p class="help-text">When enabled, shows animated starry background. Disable to improve performance on slower devices.</p>
            </div>
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
          </div>
        </section>

        <div class="text-center">
          <button type="submit" class="btn btn-primary btn-lg" disabled={saving}>
            {saving ? 'Saving...' : 'Save Settings'}
          </button>
        </div>
      </form>
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
    margin-bottom: 2rem;
    text-align: center;
  }

  .admin-header h1 {
    font-size: 2.5rem;
    font-weight: 700;
    margin: 0;
    letter-spacing: 1px;
  }

  .settings-form {
    max-width: 800px;
    margin: 0 auto;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
    color: var(--text-primary);
    font-weight: 500;
  }

  .checkbox-label input[type="checkbox"] {
    width: 1.25rem;
    height: 1.25rem;
    margin: 0;
    accent-color: var(--neon-cyan);
  }

  .help-text {
    margin: 0.5rem 0 0;
    font-size: 0.875rem;
    color: var(--text-muted);
  }

  @media (max-width: 800px) {
    .admin-container {
      padding: 1rem;
    }
    
    .admin-header h1 {
      font-size: 2rem;
    }
    
    .settings-form {
      max-width: 100%;
    }
  }
</style> 