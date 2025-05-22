<script lang="ts">
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import { onMount } from 'svelte';
  import { fade } from 'svelte/transition';

  let email = '';
  let password = '';
  let error = '';
  let loading = false;
  let logoUrl = '';

  onMount(async () => {
    try {
      const { data } = supabase.storage.from('route420').getPublicUrl('logo.png');
      logoUrl = data.publicUrl;
    } catch (err) {
      console.error('Error getting logo URL:', err);
    }
  });

  async function login() {
    loading = true;
    error = '';
    const { data: signInData, error: err } = await supabase.auth.signInWithPassword({ email, password });
    loading = false;
    if (err) {
      error = err.message;
    } else {
      // After successful login, check if profile exists
      const user = signInData.user;
      if (user) {
        const { data: profile, error: profileFetchError } = await supabase
          .from('profiles')
          .select('*')
          .eq('auth_user_id', user.id)
          .single();
        if (profileFetchError && profileFetchError.code !== 'PGRST116') {
          // PGRST116: No rows found (acceptable, means profile doesn't exist)
          error = 'Failed to check profile. Please contact support.';
          return;
        }
        if (!profile) {
          // Create profile if it doesn't exist
          const { error: profileInsertError } = await supabase
            .from('profiles')
            .insert([
              {
                id: user.id,
                display_name: user.user_metadata?.display_name || '',
                phone_number: user.user_metadata?.phone_number || '',
                email: user.email
              }
            ]);
          if (profileInsertError) {
            error = 'Failed to create profile. Please contact support.';
            return;
          }
        }
      }
      goto('/'); // or goto('/admin') if you want to redirect admins
    }
  }
</script>

<StarryBackground />

<div class="auth-container">
  <div class="auth-card">
    {#if logoUrl}
      <img src={logoUrl} alt="Logo" class="logo" />
    {/if}
    <h1>Welcome Back</h1>
    <p class="subtitle">Sign in to your account</p>

    {#if error}
      <div class="error" transition:fade>{error}</div>
    {/if}

    <form on:submit|preventDefault={login}>
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
          placeholder="Enter your password"
          required
          autocomplete="current-password"
        />
      </div>

      <button type="submit" class="submit-btn" disabled={loading}>
        {#if loading}
          <span class="loading-spinner"></span>
          Signing in...
        {:else}
          Sign In
        {/if}
      </button>
    </form>

    <p class="auth-footer">
      Don't have an account? <button type="button" class="link-btn" on:click={() => goto('/signup')}>Create one</button>
    </p>
  </div>
</div>

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

  .auth-card {
    backdrop-filter: blur(10px);
    padding: 1.5rem;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
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
    color: wheat;
    margin: 0 0 0.5rem;
    text-align: center;
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