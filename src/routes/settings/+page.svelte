<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import Navbar from '$lib/components/Navbar.svelte';
  import SideMenu from '$lib/components/SideMenu.svelte';
  import { showSnackbar } from '$lib/stores/snackbarStore';

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

  onMount(async () => {
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser) {
      goto('/login');
      return;
    }
    user = currentUser;
    email = currentUser.email || '';
    
    // Fetch profile by auth_user_id
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('auth_user_id', user.id)
      .single();
    if (profile) {
      displayName = profile.display_name || '';
      phoneNumber = profile.phone_number || '';
      address = profile.address || '';
      notifications = profile.notifications ?? true;
      darkMode = profile.dark_mode ?? false;
    } else {
      // fallback to user_metadata
      const preferences = currentUser.user_metadata || {};
      displayName = preferences.display_name || '';
      phoneNumber = preferences.phone_number || '';
      address = preferences.address || '';
      notifications = preferences.notifications ?? true;
      darkMode = preferences.dark_mode ?? false;
    }
    loading = false;
  });

  async function saveSettings() {
    loading = true;
    error = '';
    success = '';

    try {
      // Update user metadata with preferences
      const { error: updateError } = await supabase.auth.updateUser({
        data: {
          display_name: displayName,
          phone_number: phoneNumber,
          address: address,
          notifications,
          dark_mode: darkMode
        }
      });

      if (updateError) throw updateError;

      // Update profiles table
      const { error: profileError } = await supabase
        .from('profiles')
        .update({
          display_name: displayName,
          phone_number: phoneNumber
        })
        .eq('auth_user_id', user.id);

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
</script>

<Navbar 
  bind:cartButton
  onCartToggle={toggleCart} 
  onMenuToggle={toggleMenu}
  onLogoClick={() => goto('/')}
/>

<main class="settings-container">
  <h1>Settings</h1>

  {#if error}
    <div class="error-message">{error}</div>
  {/if}

  {#if success}
    <div class="success-message">{success}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading...</div>
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

<SideMenu visible={menuVisible} toggleVisibility={toggleMenu} />

<style>
  .settings-container {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1rem;
  }

  h1 {
    text-align: center;
    margin-bottom: 2rem;
    color: #333;
  }

  .settings-grid {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 2rem;
  }

  .settings-section {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  }

  h2 {
    margin-bottom: 1.5rem;
    color: #333;
    font-size: 1.5rem;
  }

  .form-group {
    margin-bottom: 1.5rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    color: #555;
    font-weight: 500;
  }

  input[type="text"],
  input[type="email"],
  input[type="tel"],
  textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 1rem;
    transition: border-color 0.2s;
  }

  input[type="text"]:focus,
  input[type="email"]:focus,
  input[type="tel"]:focus,
  textarea:focus {
    border-color: #007bff;
    outline: none;
  }

  input:disabled {
    background: #f5f5f5;
    cursor: not-allowed;
  }

  .checkbox {
    display: flex;
    align-items: center;
  }

  .checkbox label {
    display: flex;
    align-items: center;
    margin: 0;
    cursor: pointer;
  }

  .checkbox input {
    margin-right: 0.5rem;
  }

  .save-button {
    width: 100%;
    padding: 1rem;
    background: #28a745;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1.1rem;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .save-button:hover:not(:disabled) {
    background: #218838;
  }

  .save-button:disabled {
    background: #ccc;
    cursor: not-allowed;
  }

  .security-actions {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .security-button {
    padding: 0.75rem;
    background: #007bff;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .security-button:hover:not(:disabled) {
    background: #0056b3;
  }

  .delete-button {
    padding: 0.75rem;
    background: #dc3545;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .delete-button:hover:not(:disabled) {
    background: #bd2130;
  }

  .error-message {
    background: #f8d7da;
    color: #721c24;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
  }

  .success-message {
    background: #d4edda;
    color: #155724;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1rem;
  }

  .loading {
    text-align: center;
    padding: 2rem;
    color: #666;
  }

  @media (max-width: 768px) {
    .settings-grid {
      grid-template-columns: 1fr;
    }
  }
</style> 