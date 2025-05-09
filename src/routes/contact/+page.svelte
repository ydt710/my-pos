<script lang="ts">
  let name = '';
  let email = '';
  let message = '';
  let submitted = false;
  let error = '';

  function handleSubmit() {
    if (!name || !email || !message) {
      error = 'Please fill in all fields.';
      return;
    }
    submitted = true;
    error = '';
    // Here you would send the form data to your backend or email service
  }
</script>

<div class="contact-container">
  <div class="contact-card">
    <h1>Contact Us</h1>
    <p class="subtitle">We'd love to hear from you! Fill out the form below and we'll get back to you soon.</p>

    {#if submitted}
      <div class="success">Thank you for reaching out! We'll get back to you soon.</div>
    {:else}
      {#if error}
        <div class="error">{error}</div>
      {/if}
      <form on:submit|preventDefault={handleSubmit}>
        <div class="form-group">
          <label for="name">Name</label>
          <input
            id="name"
            type="text"
            bind:value={name}
            placeholder="Your Name"
            required
          />
        </div>
        <div class="form-group">
          <label for="email">Email</label>
          <input
            id="email"
            type="email"
            bind:value={email}
            placeholder="you@email.com"
            required
          />
        </div>
        <div class="form-group">
          <label for="message">Message</label>
          <textarea
            id="message"
            bind:value={message}
            placeholder="How can we help you?"
            required
          ></textarea>
        </div>
        <button type="submit" class="submit-btn">Send Message</button>
      </form>
    {/if}
  </div>
</div>

<style>
  .contact-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
  }

  .contact-card {
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

  input,
  textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
    transition: border-color 0.2s;
  }

  input:focus,
  textarea:focus {
    outline: none;
    border-color: #007bff;
  }

  textarea {
    min-height: 100px;
    resize: vertical;
  }

  .submit-btn {
    width: 100%;
    padding: 0.75rem;
    background: #007bff;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .submit-btn:hover:not(:disabled) {
    background: #0056b3;
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
</style> 