<script lang="ts">
    import { supabase } from '$lib/supabase';
    import { goto } from '$app/navigation';
  
    let email = '';
    let password = '';
    let error = '';
    let loading = false;
    let success = '';
  
    async function signup() {
      loading = true;
      error = '';
      success = '';
      const { error: err } = await supabase.auth.signUp({ email, password });
      loading = false;
      if (err) {
        error = err.message;
      } else {
        success = 'Account created! Please check your email to confirm your account.';
        // Optionally redirect after a delay:
        // setTimeout(() => goto('/login'), 2000);
      }
    }
  </script>
  
  <h1>Create Account</h1>
  {#if error}
    <div class="error">{error}</div>
  {/if}
  {#if success}
    <div class="success">{success}</div>
  {/if}
  <form on:submit|preventDefault={signup}>
    <input
      type="email"
      bind:value={email}
      placeholder="Email"
      required
      autocomplete="username"
    />
    <input
      type="password"
      bind:value={password}
      placeholder="Password"
      required
      autocomplete="new-password"
      minlength="6"
    />
    <button type="submit" disabled={loading}>
      {loading ? 'Creating...' : 'Create Account'}
    </button>
  </form>
  <p>
    Already have an account? <a href="/login">Login</a>
  </p>
  
  <style>
    form {
      margin: 2rem 0;
      display: flex;
      flex-direction: column;
      max-width: 300px;
      gap: 1rem;
    }
    input {
      padding: 0.5rem;
      font-size: 1rem;
    }
    .error {
      color: red;
      margin-bottom: 1rem;
    }
    .success {
      color: green;
      margin-bottom: 1rem;
    }
    button {
      padding: 0.5rem;
      font-size: 1rem;
      background: #28a745;
      color: white;
      border: none;
      border-radius: 5px;
      cursor: pointer;
    }
    button:disabled {
      background: #aaa;
      cursor: not-allowed;
    }
  </style>