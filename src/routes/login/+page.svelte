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
          .maybeSingle();
        if (profileFetchError && profileFetchError.code !== 'PGRST116' && profileFetchError.code !== '406') {
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
                auth_user_id: user.id,
                email: user.email
              }
            ]);
          // If error is not a duplicate key/409, show error
          if (profileInsertError && profileInsertError.code !== '23505' && profileInsertError.code !== '409') {
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
  <div class="auth-card glass">
    {#if logoUrl}
      <div class="logo-container">
        <img src={logoUrl} alt="Logo" class="logo" />
      </div>
    {/if}
    
    <div class="auth-header">
      <h1 class="neon-text-cyan">Welcome Back</h1>
      <p class="neon-text-white auth-subtitle">Sign in to your account</p>
    </div>

    {#if error}
      <div class="alert alert-error" transition:fade>
        <div class="alert-content">
          <span class="alert-icon">⚠️</span>
          <span>{error}</span>
        </div>
      </div>
    {/if}

    <form on:submit|preventDefault={login} class="auth-form">
      <div class="form-group">
        <label for="email" class="form-label neon-text-white">
          <span class="label-icon">📧</span>
          Email Address
        </label>
        <input
          id="email"
          type="email"
          bind:value={email}
          placeholder="Enter your email"
          required
          autocomplete="username"
          class="form-control neon-input"
        />
      </div>

      <div class="form-group">
        <label for="password" class="form-label neon-text-white">
          <span class="label-icon">🔒</span>
          Password
        </label>
        <input
          id="password"
          type="password"
          bind:value={password}
          placeholder="Enter your password"
          required
          autocomplete="current-password"
          class="form-control neon-input"
        />
      </div>

      <button type="submit" class="btn btn-primary btn-large" disabled={loading}>
        {#if loading}
          <span class="loading-spinner"></span>
          Signing in...
        {:else}
          <span class="btn-icon">🚀</span>
          Sign In
        {/if}
      </button>
    </form>

    <div class="auth-footer">
      <p class="neon-text-secondary">
        Don't have an account? 
        <button type="button" class="link-btn neon-text-cyan" on:click={() => goto('/signup')}>
          Create one
        </button>
      </p>
    </div>
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
    max-width: 450px;
    width: 100%;
    padding: 2rem;
    backdrop-filter: blur(20px);
    border: 1px solid var(--border-neon);
    box-shadow: var(--shadow-neon), 0 8px 32px rgba(0, 242, 254, 0.1);
    position: relative;
    overflow: hidden;
  }

  .auth-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--gradient-primary);
    opacity: 0.8;
  }

  .logo-container {
    text-align: center;
    margin-bottom: 2rem;
  }

  .logo {
    width: 120px;
    height: auto;
    filter: drop-shadow(0 0 10px rgba(0, 242, 254, 0.3));
    transition: all 0.3s ease;
  }

  .logo:hover {
    filter: drop-shadow(0 0 20px rgba(0, 242, 254, 0.6));
    transform: scale(1.05);
  }

  .auth-header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .auth-header h1 {
    font-size: 2.5rem;
    margin: 0 0 0.5rem;
    font-weight: 700;
    text-shadow: var(--text-shadow-neon);
    letter-spacing: 0.02em;
  }

  .auth-subtitle {
    font-size: 1.1rem;
    margin: 0;
    opacity: 0.9;
    letter-spacing: 0.01em;
  }

  .auth-form {
    margin-bottom: 2rem;
  }

  .form-group {
    margin-bottom: 1.5rem;
  }

  .form-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
    font-weight: 600;
    font-size: 0.95rem;
    letter-spacing: 0.01em;
  }

  .label-icon {
    font-size: 1.1rem;
    opacity: 0.8;
  }

  .neon-input {
    width: 100%;
    background: rgba(13, 17, 23, 0.8);
    border: 1px solid rgba(0, 242, 254, 0.3);
    color: var(--text-primary);
    font-size: 1rem;
    transition: all 0.3s ease;
    text-align: center;
  }

  .neon-input:focus {
    outline: none;
    border-color: var(--neon-cyan);
    box-shadow: 0 0 0 2px rgba(0, 242, 254, 0.2), inset 0 0 20px rgba(0, 242, 254, 0.05);
    background: rgba(0, 242, 254, 0.05);
  }

  .neon-input::placeholder {
    color: rgba(255, 255, 255, 0.5);
    font-style: italic;
  }

  .btn-large {
    width: 100%;
    padding: 0.875rem 1.5rem;
    font-size: 1.1rem;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    position: relative;
    overflow: hidden;
  }

  .btn-large::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
    transition: left 0.5s;
  }

  .btn-large:hover::before {
    left: 100%;
  }

  .btn-icon {
    font-size: 1.2rem;
  }

  .alert {
    margin-bottom: 1.5rem;
    padding: 1rem;
    border-radius: 8px;
    border: 1px solid;
    backdrop-filter: blur(10px);
  }

  .alert-error {
    background: rgba(220, 53, 69, 0.1);
    border-color: rgba(220, 53, 69, 0.3);
    color: #ff6b7a;
  }

  .alert-content {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .alert-icon {
    font-size: 1.2rem;
  }

  .auth-footer {
    text-align: center;
    padding-top: 1.5rem;
    border-top: 1px solid rgba(0, 242, 254, 0.2);
  }

  .auth-footer p {
    margin: 0;
    font-size: 0.95rem;
  }

  .link-btn {
    background: none;
    border: none;
    font-weight: 600;
    cursor: pointer;
    padding: 0;
    font: inherit;
    text-decoration: none;
    transition: all 0.3s ease;
    position: relative;
  }

  .link-btn::after {
    content: '';
    position: absolute;
    bottom: -2px;
    left: 0;
    width: 0;
    height: 2px;
    background: var(--gradient-primary);
    transition: width 0.3s ease;
  }

  .link-btn:hover::after {
    width: 100%;
  }

  .link-btn:hover {
    text-shadow: 0 0 8px rgba(0, 242, 254, 0.6);
    transform: translateY(-1px);
  }

  .loading-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-radius: 50%;
    border-top-color: #fff;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  /* Mobile Responsiveness */
  @media (max-width: 768px) {
    .auth-container {
      padding: 1rem;
    }

    .auth-card {
      padding: 1.5rem;
      max-width: 100%;
    }

    .auth-header h1 {
      font-size: 2rem;
    }

    .logo {
      width: 100px;
    }
  }

  @media (max-width: 480px) {
    .auth-container {
      padding: 0.75rem;
    }

    .auth-card {
      padding: 1.25rem;
    }

    .auth-header h1 {
      font-size: 1.75rem;
    }

    .auth-subtitle {
      font-size: 1rem;
    }

    .form-label {
      font-size: 0.9rem;
    }

    .neon-input {
      font-size: 0.95rem;
    }

    .btn-large {
      padding: 0.75rem 1.25rem;
      font-size: 1rem;
    }

    .logo {
      width: 80px;
    }
  }

  /* Enhanced glow effects for premium feel */
  @media (min-width: 769px) {
    .auth-card:hover {
      box-shadow: var(--shadow-neon), 0 12px 40px rgba(0, 242, 254, 0.15);
      transform: translateY(-2px);
    }

    .neon-input:hover {
      border-color: rgba(0, 242, 254, 0.5);
    }
  }

  /* Dark mode enhancements */
  @media (prefers-color-scheme: dark) {
    .neon-input {
      background: rgba(0, 0, 0, 0.6);
    }
  }
</style>