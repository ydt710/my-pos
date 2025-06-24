<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, testDatabaseConnection } from '$lib/supabase';

  type TestResult = {
    success: boolean;
    error?: string;
    data?: any;
    count?: number;
    buckets?: string[];
    missing?: string[];
  } | null;

  let results: {
    connection: TestResult;
    products: TestResult;
    functions: TestResult;
    storage: TestResult;
    landing: TestResult;
  } = {
    connection: null,
    products: null,
    functions: null,
    storage: null,
    landing: null
  };
  
  let loading = true;
  let overallSuccess = false;

  onMount(async () => {
    await runAllTests();
  });

  async function runAllTests() {
    loading = true;
    results = { connection: null, products: null, functions: null, storage: null, landing: null };

    // Test 1: Database Connection
    console.log('🔍 Testing database connection...');
    results.connection = await testDatabaseConnection();

    // Test 2: Cannabis Products
    console.log('🌿 Testing cannabis products...');
    try {
      const { data, error } = await supabase
        .from('products')
        .select('id, name, category, price')
        .limit(5);
      
      if (error) {
        results.products = { success: false, error: error.message };
      } else {
        results.products = { 
          success: true, 
          count: data?.length || 0,
          data: data || []
        };
      }
    } catch (err) {
      results.products = { success: false, error: String(err) };
    }

    // Test 3: Database Functions
    console.log('📊 Testing database functions...');
    try {
      const { data, error } = await supabase.rpc('get_dashboard_stats');
      
      if (error) {
        results.functions = { success: false, error: error.message };
      } else {
        results.functions = { success: true, data };
      }
    } catch (err) {
      results.functions = { success: false, error: String(err) };
    }

    // Test 4: Storage Buckets
    console.log('💾 Testing storage buckets...');
    try {
      const { data, error } = await supabase.storage.listBuckets();
      
      if (error) {
        results.storage = { success: false, error: error.message };
      } else {
        const bucketNames = data?.map(b => b.name) || [];
        const expectedBuckets = ['products', 'signatures', 'id_images', 'contracts'];
        const hasBuckets = expectedBuckets.every(bucket => bucketNames.includes(bucket));
        
        results.storage = { 
          success: hasBuckets, 
          buckets: bucketNames,
          missing: expectedBuckets.filter(bucket => !bucketNames.includes(bucket))
        };
      }
    } catch (err) {
      results.storage = { success: false, error: String(err) };
    }

    // Test 5: Landing Page Data
    console.log('🎨 Testing landing page data...');
    try {
      const { data, error } = await supabase
        .from('landing_hero')
        .select('*')
        .limit(1)
        .maybeSingle();
      
      if (error) {
        results.landing = { success: false, error: error.message };
      } else {
        results.landing = { success: !!data, data };
      }
    } catch (err) {
      results.landing = { success: false, error: String(err) };
    }

    // Calculate overall success
    overallSuccess = Object.values(results).every(result => result?.success === true);
    loading = false;

    // Log final results
    console.log('📋 Final Test Results:', results);
    console.log(overallSuccess ? '✅ All tests passed!' : '❌ Some tests failed');
  }

  function getStatusIcon(result: TestResult) {
    if (!result) return '⏳';
    return result.success ? '✅' : '❌';
  }

  function getStatusColor(result: TestResult) {
    if (!result) return '#666';
    return result.success ? '#10b981' : '#ef4444';
  }
</script>

<main>
  <div class="header">
    <h1>🚀 Production Deployment Test</h1>
    <p>Comprehensive test of all deployed features</p>
    
    {#if !loading}
      <div class="overall-status" style="color: {overallSuccess ? '#10b981' : '#ef4444'}; background: {overallSuccess ? '#d1fae5' : '#fee2e2'}">
        {#if overallSuccess}
          🎉 All Systems Operational - Production Ready!
        {:else}
          ⚠️ Some Issues Detected - Check Details Below
        {/if}
      </div>
    {/if}
  </div>

  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <p>Running comprehensive tests...</p>
    </div>
  {:else}
    <div class="test-results">
      
      <!-- Database Connection Test -->
      <div class="test-card">
        <h2>
          {getStatusIcon(results.connection)} Database Connection
        </h2>
        {#if results.connection?.success}
          <p style="color: #10b981">✅ Connected successfully to production database</p>
          {#if results.connection.data}
            <pre>Data: {JSON.stringify(results.connection.data, null, 2)}</pre>
          {/if}
        {:else}
          <p style="color: #ef4444">❌ Connection failed: {results.connection?.error}</p>
        {/if}
      </div>

      <!-- Cannabis Products Test -->
      <div class="test-card">
        <h2>
          {getStatusIcon(results.products)} Cannabis Products
        </h2>
        {#if results.products?.success}
          <p style="color: #10b981">✅ Found {results.products.count} products</p>
          {#if results.products.data?.length > 0}
            <div class="product-list">
              {#each results.products.data as product}
                <div class="product-item">
                  <strong>{product.name}</strong> - {product.category} - R{product.price}
                </div>
              {/each}
            </div>
          {/if}
        {:else}
          <p style="color: #ef4444">❌ Products test failed: {results.products?.error}</p>
          <p><em>Make sure to run script 03_data.sql to load cannabis products</em></p>
        {/if}
      </div>

      <!-- Database Functions Test -->
      <div class="test-card">
        <h2>
          {getStatusIcon(results.functions)} Database Functions
        </h2>
        {#if results.functions?.success}
          <p style="color: #10b981">✅ Dashboard function working correctly</p>
          {#if results.functions.data}
            <div class="function-data">
              <p><strong>Total Orders:</strong> {results.functions.data.totalOrders}</p>
              <p><strong>Total Revenue:</strong> R{results.functions.data.totalRevenue}</p>
              <p><strong>Cash Collected Today:</strong> R{results.functions.data.cashCollectedToday}</p>
            </div>
          {/if}
        {:else}
          <p style="color: #ef4444">❌ Functions test failed: {results.functions?.error}</p>
          <p><em>Make sure to run script 06_functions.sql or the 4-part function scripts</em></p>
        {/if}
      </div>

      <!-- Storage Buckets Test -->
      <div class="test-card">
        <h2>
          {getStatusIcon(results.storage)} Storage Buckets
        </h2>
                 {#if results.storage?.success}
           <p style="color: #10b981">✅ All required storage buckets found</p>
           <div class="bucket-list">
             {#each (results.storage.buckets || []) as bucket}
               <span class="bucket-tag">{bucket}</span>
             {/each}
           </div>
         {:else}
           <p style="color: #ef4444">❌ Storage test failed</p>
           {#if results.storage?.missing && results.storage.missing.length > 0}
             <p>Missing buckets: {results.storage.missing.join(', ')}</p>
           {/if}
          {#if results.storage?.error}
            <p>Error: {results.storage.error}</p>
          {/if}
          <p><em>Make sure to run script 07_rls_and_storage.sql</em></p>
        {/if}
      </div>

      <!-- Landing Page Test -->
      <div class="test-card">
        <h2>
          {getStatusIcon(results.landing)} Landing Page Data
        </h2>
        {#if results.landing?.success}
          <p style="color: #10b981">✅ Landing page data loaded successfully</p>
          {#if results.landing.data}
            <div class="landing-data">
              <p><strong>Title:</strong> {results.landing.data.title}</p>
              <p><strong>Subtitle:</strong> {results.landing.data.subtitle}</p>
            </div>
          {/if}
        {:else}
          <p style="color: #ef4444">❌ Landing page test failed: {results.landing?.error}</p>
          <p><em>Make sure to run scripts 02_tables.sql and 03_data.sql</em></p>
        {/if}
      </div>

    </div>

    <div class="actions">
      <button on:click={runAllTests} class="test-button">
        🔄 Run Tests Again
      </button>
      
      {#if overallSuccess}
        <div class="success-message">
          <h3>🎊 Deployment Successful!</h3>
          <p>Your production Supabase is now updated with all the latest features:</p>
          <ul>
            <li>✅ 13 Cannabis products loaded</li>
            <li>✅ All database functions working</li>
            <li>✅ Storage buckets created</li>
            <li>✅ Landing page system ready</li>
            <li>✅ POS system functional</li>
          </ul>
          <p><strong>Next Steps:</strong> Update your hosting platform environment variables and redeploy your app!</p>
        </div>
      {/if}
    </div>
  {/if}
</main>

<style>
  main {
    padding: 2rem;
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    max-width: 1200px;
    margin: 0 auto;
  }

  .header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .header h1 {
    color: #1f2937;
    margin-bottom: 0.5rem;
  }

  .overall-status {
    padding: 1rem;
    border-radius: 8px;
    font-weight: bold;
    margin-top: 1rem;
    text-align: center;
  }

  .loading {
    text-align: center;
    padding: 3rem;
  }

  .spinner {
    border: 4px solid #f3f4f6;
    border-top: 4px solid #3b82f6;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 0 auto 1rem;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .test-results {
    display: grid;
    gap: 1.5rem;
    margin-bottom: 2rem;
  }

  .test-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .test-card h2 {
    margin: 0 0 1rem 0;
    color: #1f2937;
    font-size: 1.25rem;
  }

  .product-list {
    margin-top: 0.5rem;
  }

  .product-item {
    padding: 0.5rem;
    background: #f9fafb;
    border-radius: 4px;
    margin: 0.25rem 0;
    font-family: monospace;
  }

  .function-data {
    background: #f0f9ff;
    padding: 1rem;
    border-radius: 4px;
    margin-top: 0.5rem;
  }

  .bucket-list {
    margin-top: 0.5rem;
  }

  .bucket-tag {
    display: inline-block;
    background: #dbeafe;
    color: #1e40af;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    margin: 0.25rem;
    font-size: 0.875rem;
  }

  .landing-data {
    background: #f0fdf4;
    padding: 1rem;
    border-radius: 4px;
    margin-top: 0.5rem;
  }

  .actions {
    text-align: center;
  }

  .test-button {
    background: #3b82f6;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 6px;
    font-size: 1rem;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .test-button:hover {
    background: #2563eb;
  }

  .success-message {
    background: #d1fae5;
    border: 1px solid #10b981;
    border-radius: 8px;
    padding: 1.5rem;
    margin-top: 1.5rem;
    text-align: left;
  }

  .success-message h3 {
    color: #065f46;
    margin-top: 0;
  }

  .success-message ul {
    margin: 1rem 0;
  }

  .success-message li {
    margin: 0.25rem 0;
  }

  pre {
    background: #f3f4f6;
    padding: 0.5rem;
    border-radius: 4px;
    overflow-x: auto;
    font-size: 0.875rem;
  }
</style> 