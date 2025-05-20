<script lang="ts">
    import { supabase } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import StarryBackground from '$lib/components/StarryBackground.svelte';
    import { onMount } from 'svelte';
    import { fade } from 'svelte/transition';
  
    let email = '';
    let password = '';
    let displayName = '';
    let phoneNumber = '';
    let error = '';
    let loading = false;
    let success = '';
    let logoUrl = '';

    onMount(async () => {
      try {
        const { data } = supabase.storage.from('route420').getPublicUrl('logo.png');
        logoUrl = data.publicUrl;
      } catch (err) {
        console.error('Error getting logo URL:', err);
      }
    });
  
    async function signup() {
      loading = true;
      error = '';
      success = '';
      const { data: signUpData, error: err } = await supabase.auth.signUp({ 
        email, 
        password,
        options: {
          data: {
            display_name: displayName,
            phone_number: phoneNumber
          }
        }
      });
      
      if (err) {
        error = err.message;
        loading = false;
        return;
      }

      // Profile creation is now handled after login

      loading = false;
      success = 'Account created! Please check your email to confirm your account.';
      // Optionally redirect after a delay:
      // setTimeout(() => goto('/login'), 2000);
    }
  </script>
  
  <StarryBackground />
  
  <div class="auth-container">
    <div class="auth-card">
      {#if logoUrl}
        <img src={logoUrl} alt="Logo" class="logo" />
      {/if}
      <h1>Create Account</h1>
      <p class="subtitle">Join us today</p>

      {#if error}
        <div class="error" transition:fade>{error}</div>
      {/if}
      {#if success}
        <div class="success" transition:fade>{success}</div>
      {/if}

      <form on:submit|preventDefault={signup}>
        <div class="form-group">
          <label for="displayName">Display Name</label>
          <input
            id="displayName"
            type="text"
            bind:value={displayName}
            placeholder="Enter your display name"
            required
          />
        </div>

        <div class="form-group">
          <label for="phoneNumber">Phone Number</label>
          <input
            id="phoneNumber"
            type="tel"
            bind:value={phoneNumber}
            placeholder="Enter your phone number"
            required
          />
        </div>

        <div class="form-group">
          <label for="email">Email</label>
          <input
            id="email"
            type="email"
            bind:value={email}
            placeholder="Enter your email"
            required
            autocomplete="username"
          />
        </div>

        <div class="form-group">
          <label for="password">Password</label>
          <input
            id="password"
            type="password"
            bind:value={password}
            placeholder="Create a password"
            required
            autocomplete="new-password"
            minlength="6"
          />
          <small class="password-hint">Password must be at least 6 characters long</small>
        </div>

        <button type="submit" class="submit-btn" disabled={loading}>
          {#if loading}
            <span class="loading-spinner"></span>
            Creating Account...
          {:else}
            Create Account
          {/if}
        </button>
      </form>

      <p class="auth-footer">
        Already have an account? <button type="button" class="link-btn" on:click={() => goto('/login')}>Sign in</button>
      </p>
    </div>
  </div>

  <style>
    .auth-container {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 2rem;
      position: relative;
      z-index: 1;
    }

    .auth-card {
      background: rgba(255, 255, 255, 0.9);
      backdrop-filter: blur(10px);
      padding: 2.5rem;
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      width: 100%;
      max-width: 400px;
      border: 1px solid rgba(255, 255, 255, 0.2);
    }

    .logo {
      width: 120px;
      height: auto;
      margin: 0 auto 2rem;
      display: block;
    }

    h1 {
      font-size: 2rem;
      color: #333;
      margin: 0 0 0.5rem;
      text-align: center;
    }

    .subtitle {
      color: #666;
      text-align: center;
      margin-bottom: 2rem;
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

    input {
      width: 100%;
      border: 1px solid rgba(0, 0, 0, 0.1);
      border-radius: 8px;
      font-size: 1rem;
      transition: all 0.2s;
      background: rgba(255, 255, 255, 0.9);
    }

    input:focus {
      outline: none;
      border-color: #2196f3;
      box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
    }

    .password-hint {
      display: block;
      margin-top: 0.5rem;
      color: #666;
      font-size: 0.875rem;
    }

    .submit-btn {
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
    }

    .submit-btn:hover:not(:disabled) {
      background: linear-gradient(135deg, #1976d2, #1565c0);
      transform: translateY(-1px);
      box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
    }

    .submit-btn:disabled {
      background: #e0e0e0;
      cursor: not-allowed;
    }

    .error {
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

      .auth-card {
        padding: 1.5rem;
      }

      h1 {
        font-size: 1.75rem;
      }
    }
  </style>