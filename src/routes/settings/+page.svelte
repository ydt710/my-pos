<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import { showSnackbar } from '$lib/stores/snackbarStore';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';

  let user: any = null;
  let loading = true;
  let error = '';
  let success = '';
  let menuVisible = false;
  let cartVisible = false;
  let cartButton: HTMLButtonElement;

  // User settings
  let email = '';
  let displayName = '';
  let phoneNumber = '';
  let address = '';
  let notifications = true;
  let darkMode = false;
  let signedContractUrl: string | null = null;

  onMount(async () => {
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser) {
      goto('/login');
      return;
    }
    user = currentUser;
    email = currentUser.email || '';
    
    // Fetch profile by auth_user_id
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('auth_user_id', user.id)
      .maybeSingle();
    if (profileError && profileError.code !== 'PGRST116' && profileError.code !== '406') {
      error = 'Failed to fetch profile. Please contact support.';
      loading = false;
      return;
    }
    if (profile) {
      displayName = profile.display_name || '';
      phoneNumber = profile.phone_number || '';
      address = profile.address || '';
      notifications = profile.notifications ?? true;
      darkMode = profile.dark_mode ?? false;
      signedContractUrl = profile.signed_contract_url || null;
    } else {
      displayName = '';
      phoneNumber = '';
      address = '';
      notifications = true;
      darkMode = false;
      signedContractUrl = null;
    }
    loading = false;
  });

  async function saveSettings() {
    loading = true;
    error = '';
    success = '';

    try {
      // Use upsert to create a profile if it doesn't exist, or update it if it does.
      const { error: profileError } = await supabase
        .from('profiles')
        .upsert({
          auth_user_id: user.id,
          display_name: displayName,
          phone_number: phoneNumber,
          address: address,
          notifications: notifications,
          dark_mode: darkMode
        }, {
          onConflict: 'auth_user_id'
        });

      if (profileError) throw profileError;

      success = 'Settings saved successfully!';
    } catch (err) {
      console.error('Error saving settings:', err);
      error = 'Failed to save settings. Please try again.';
    } finally {
      loading = false;
    }
  }

  async function updatePassword() {
    const newPassword = prompt('Enter new password (min 6 characters):');
    if (!newPassword || newPassword.length < 6) {
      error = 'Password must be at least 6 characters long.';
      return;
    }

    loading = true;
    error = '';
    success = '';

    try {
      const { error: updateError } = await supabase.auth.updateUser({
        password: newPassword
      });

      if (updateError) throw updateError;

      success = 'Password updated successfully!';
    } catch (err) {
      console.error('Error updating password:', err);
      error = 'Failed to update password. Please try again.';
    } finally {
      loading = false;
    }
  }

  async function deleteAccount() {
    // TODO: Replace with a proper confirmation modal
    showSnackbar('Account deletion confirmation not implemented. Please add a modal.');
    return;
    // if (!confirm('Are you sure you want to delete your account? This action cannot be undone.')) {
    //   return;
    // }

    loading = true;
    error = '';
    success = '';

    try {
      const { error: deleteError } = await supabase.auth.admin.deleteUser(user.id);
      if (deleteError) throw deleteError;

      await supabase.auth.signOut();
      goto('/');
    } catch (err) {
      console.error('Error deleting account:', err);
      error = 'Failed to delete account. Please try again.';
      loading = false;
    }
  }

  function toggleMenu() {
    menuVisible = !menuVisible;
    if (cartVisible) cartVisible = false;
  }

  function toggleCart() {
    cartVisible = !cartVisible;
    if (menuVisible) menuVisible = false;
  }

  async function handleDownloadContract() {
    if (signedContractUrl) {
      // Always use createSignedUrl for private bucket
      const { data, error } = await supabase.storage
        .from('signed.contracts')
        .createSignedUrl(signedContractUrl, 600); // 10 minutes
      if (data && data.signedUrl) {
        window.open(data.signedUrl, '_blank');
      } else {
        showSnackbar('Could not generate download link. Please try again.');
      }
    } else {
      showSnackbar('No contract file found.');
    }
  }
</script>

<StarryBackground />
<main class="settings-container">
  <h1>Settings</h1>

  {#if error}
    <div class="error-message">{error}</div>
  {/if}

  {#if success}
    <div class="success">{success}</div>
  {/if}

  {#if signedContractUrl}
    <div class="success" style="margin-bottom: 1.5rem;">
      <p>Your signed contract is available.</p>
      <button type="button" class="submit-btn" on:click={handleDownloadContract}>
        Download Signed Contract
      </button>
    </div>
  {/if}

  {#if loading}
    <LoadingSpinner />
  {:else}
    <div class="settings-grid">
      <section class="settings-section">
        <h2>Profile Settings</h2>
        <form on:submit|preventDefault={saveSettings}>
          <div class="form-group">
            <label for="email">Email</label>
            <input 
              type="email" 
              id="email" 
              bind:value={email} 
              disabled
            />
          </div>

          <div class="form-group">
            <label for="displayName">Display Name</label>
            <input 
              type="text" 
              id="displayName" 
              bind:value={displayName} 
              placeholder="Enter your display name"
            />
          </div>

          <div class="form-group">
            <label for="phoneNumber">Phone Number</label>
            <input 
              type="tel" 
              id="phoneNumber" 
              bind:value={phoneNumber} 
              placeholder="Enter your phone number"
            />
          </div>

          <div class="form-group">
            <label for="address">Delivery Address</label>
            <textarea 
              id="address" 
              bind:value={address} 
              placeholder="Enter your delivery address"
              rows="3"
            ></textarea>
          </div>

          <div class="form-group checkbox">
            <label>
              <input 
                type="checkbox" 
                bind:checked={notifications}
              />
              Receive order notifications
            </label>
          </div>

          <div class="form-group checkbox">
            <label>
              <input 
                type="checkbox" 
                bind:checked={darkMode}
              />
              Dark Mode
            </label>
          </div>

          <button type="submit" class="save-button" disabled={loading}>
            {loading ? 'Saving...' : 'Save Changes'}
          </button>
        </form>
      </section>

      <section class="settings-section">
        <h2>Account Security</h2>
        <div class="security-actions">
          <button 
            class="security-button" 
            on:click={updatePassword}
            disabled={loading}
          >
            Change Password
          </button>
          <button 
            class="delete-button" 
            on:click={deleteAccount}
            disabled={loading}
          >
            Delete Account
          </button>
        </div>
      </section>
    </div>
  {/if}
</main>

<style>
input {
  text-align: center;
}

  .auth-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    position: relative;
    z-index: 1;
  }

  .auth-card, .settings-container {
    backdrop-filter: blur(10px);
    padding: 1.5rem;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    max-width: 400px;
    border: 1px solid rgba(255, 255, 255, 0.2);
    margin: 2rem auto;
  }

  .logo {
    width: 120px;
    height: auto;
    margin: 0 auto 2rem;
    display: block;
  }

  h1 {
    font-size: 2rem;
    color: wheat;
    margin: 0 0 0.5rem;
    text-align: center;
  }

  h2 {
    font-size: 1.5rem;
    color: wheat;
    text-align: center;
    margin-top: 2rem;
    margin-bottom: 1.5rem;
  }

  .subtitle {
    color: #ffffff;
    text-align: center;
    margin-bottom: 2rem;
  }

  .form-group {
    margin-bottom: 1.5rem;
    text-align: center;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    color: #e0e0e0;
    font-weight: 500;
  }

  input, textarea {
    width: 100%;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    font-size: 1rem;
    transition: all 0.2s;
    background: rgba(255, 255, 255, 0.9);
  }

  input:focus, textarea:focus {
    outline: none;
    border-color: #2196f3;
    box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
  }

  .submit-btn, .save-button, .security-button, .delete-button {
    width: 100%;
    padding: 0.75rem;
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }

  .submit-btn:hover:not(:disabled), .save-button:hover:not(:disabled), .security-button:hover:not(:disabled) {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
  }

  .submit-btn:disabled, .save-button:disabled, .security-button:disabled {
    background: #e0e0e0;
    cursor: not-allowed;
  }

  .delete-button {
    background: #dc3545;
  }
  .delete-button:hover:not(:disabled) {
    background: #bd2130;
  }

  .error, .error-message {
    background: rgba(248, 215, 218, 0.9);
    color: #721c24;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    text-align: center;
    backdrop-filter: blur(4px);
  }

  .success {
    background: rgba(212, 237, 218, 0.9);
    color: #155724;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    text-align: center;
    backdrop-filter: blur(4px);
  }

  .auth-footer {
    text-align: center;
    margin-top: 1.5rem;
    color: #666;
  }

  .link-btn {
    background: none;
    border: none;
    color: #2196f3;
    text-decoration: underline;
    font-weight: 500;
    cursor: pointer;
    padding: 0;
    font: inherit;
  }

  .link-btn:hover {
    text-decoration: none;
  }

  .loading-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid #ffffff;
    border-radius: 50%;
    border-top-color: transparent;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  @media (max-width: 480px) {
    .auth-container {
      padding: 1rem;
    }

    .auth-card, .settings-container {
      padding: 1.5rem;
    }

    h1 {
      font-size: 1.75rem;
    }
  }
</style> 