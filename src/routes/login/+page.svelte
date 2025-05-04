<script lang="ts">
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';

  let email = '';
  let password = '';
  let error = '';
  let loading = false;

  async function login() {
    loading = true;
    error = '';
    const { error: err } = await supabase.auth.signInWithPassword({ email, password });
    loading = false;
    if (err) {
      error = err.message;
    } else {
      goto('/'); // or goto('/admin') if you want to redirect admins
    }
  }
</script>

<h1>Login</h1>
{#if error}
  <div class="error">{error}</div>
{/if}
<form on:submit|preventDefault={login}>
  <input
    type="email"
    bind:value={email}
    placeholder="Email"
    required
    autocomplete="username"
  />
  <p>
    Don't have an account? <a href="/signup">Create one</a>
  </p>
  <input
    type="password"
    bind:value={password}
    placeholder="Password"
    required
    autocomplete="current-password"
  />
  <button type="submit" disabled={loading}>
    {loading ? 'Logging in...' : 'Login'}
  </button>
</form>

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
  button {
    padding: 0.5rem;
    font-size: 1rem;
    background: #007bff;
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