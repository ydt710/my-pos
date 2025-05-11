<script lang="ts">
    import { supabase } from '$lib/supabase';
    import { goto } from '$app/navigation';
  
    let email = '';
    let password = '';
    let displayName = '';
    let phoneNumber = '';
    let error = '';
    let loading = false;
    let success = '';
  
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
  
  <div class="auth-container">
    <div class="auth-card">
      <h1>Create Account</h1>
      <p class="subtitle">Join us today</p>

      {#if error}
        <div class="error">{error}</div>
      {/if}
      {#if success}
        <div class="success">{success}</div>
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
          {loading ? 'Creating Account...' : 'Create Account'}
        </button>
      </form>

      <p class="auth-footer">
        Already have an account? <a href="/login">Sign in</a>
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
      background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
    }

    .auth-card {
      background: white;
      padding: 2.5rem;
      border-radius: 16px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      width: 100%;
      max-width: 400px;
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
      padding: 0.75rem;
      border: 1px solid #ddd;
      border-radius: 8px;
      font-size: 1rem;
      transition: border-color 0.2s;
    }

    input:focus {
      outline: none;
      border-color: #28a745;
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
      background: #28a745;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: background-color 0.2s;
    }

    .submit-btn:hover:not(:disabled) {
      background: #218838;
    }

    .submit-btn:disabled {
      background: #ccc;
      cursor: not-allowed;
    }

    .error {
      background: #f8d7da;
      color: #721c24;
      padding: 1rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      text-align: center;
    }

    .success {
      background: #d4edda;
      color: #155724;
      padding: 1rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      text-align: center;
    }

    .auth-footer {
      text-align: center;
      margin-top: 1.5rem;
      color: #666;
    }

    .auth-footer a {
      color: #28a745;
      text-decoration: none;
      font-weight: 500;
    }

    .auth-footer a:hover {
      text-decoration: underline;
    }
  </style>