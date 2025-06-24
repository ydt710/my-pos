<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';

  let menuOpen = false;

  async function handleLogout() {
    await supabase.auth.signOut();
    goto('/login');
  }

  // This function is no longer needed as we are moving to a page-based navigation
  /*
  function scrollToSection(sectionId: string) {
    if ($page.url.pathname === '/admin') {
      const element = document.getElementById(sectionId);
      if (element) {
        const navHeight = 60;
        const elementPosition = element.getBoundingClientRect().top;
        const offsetPosition = elementPosition + window.pageYOffset - navHeight;
        
        window.scrollTo({
          top: offsetPosition,
          behavior: "smooth"
        });
      }
    } else {
      goto('/admin');
      // Add a small delay to ensure the page loads before scrolling
      setTimeout(() => {
        const element = document.getElementById(sectionId);
        if (element) {
          const navHeight = 60;
          const elementPosition = element.getBoundingClientRect().top;
          const offsetPosition = elementPosition + window.pageYOffset - navHeight;
          
          window.scrollTo({
            top: offsetPosition,
            behavior: "smooth"
          });
        }
      }, 100);
    }
  }
  */
</script>

<nav class="admin-nav glass">
  <div class="nav-content">
    <div class="nav-brand">
      <button class="menu-toggle btn btn-secondary btn-sm" on:click={() => menuOpen = !menuOpen} aria-label="Toggle menu">
        ☰
      </button>
      <span class="brand-text neon-text-cyan">Admin Dashboard</span>
    </div>

    <div class="nav-links" class:open={menuOpen}>
      <a 
        href="/"
        class="nav-link {$page.url.pathname === '/' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Home
      </a>
      <a 
        href="/admin"
        class="nav-link {$page.url.pathname === '/admin' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Dashboard
      </a>
      <a 
        href="/admin/products"
        class="nav-link {$page.url.pathname === '/admin/products' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Products
      </a>
      <a 
        href="/admin/orders"
        class="nav-link {$page.url.pathname === '/admin/orders' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Orders
      </a>
      <a 
        href="/admin/users"
        class="nav-link {$page.url.pathname === '/admin/users' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Users
      </a>
      <a 
        href="/admin/settings"
        class="nav-link {$page.url.pathname === '/admin/settings' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Settings
      </a>
      <a 
        href="/admin/landing"
        class="nav-link {$page.url.pathname === '/admin/landing' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Landing Page
      </a>
      <a 
        href="/admin/stock-management"
        class="nav-link {$page.url.pathname === '/admin/stock-management' ? 'active' : ''}" 
        on:click={() => menuOpen = false}
      >
        Stock
      </a>
      <button 
        class="nav-link logout-btn" 
        on:click={handleLogout}
        on:keydown={(e) => e.key === 'Enter' && handleLogout()}
      >
        Logout
      </button>
    </div>
  </div>
</nav>

<style>
  .admin-nav {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
    border-radius: 0 0 12px 12px;
    border-top: none;
  }

  .nav-content {
    max-width: 1400px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 2rem;
  }

  .nav-brand {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .brand-text {
    font-size: 1.25rem;
    font-weight: 600;
  }

  .menu-toggle {
    display: none;
  }

  .nav-links {
    display: flex;
    align-items: center;
    gap: 1.5rem;
  }

  .nav-link {
    color: var(--text-secondary);
    text-decoration: none;
    padding: 0.75rem 1rem;
    border-radius: 8px;
    transition: var(--transition-fast);
    background: none;
    border: none;
    font-size: inherit;
    cursor: pointer;
    display: inline-block;
    font-family: inherit;
  }

  .nav-link:hover {
    color: var(--neon-cyan);
    background: var(--bg-glass-light);
    box-shadow: 0 0 10px rgba(0, 240, 255, 0.3);
  }

  .nav-link.active {
    color: var(--neon-cyan);
    background: var(--bg-glass-light);
    box-shadow: var(--shadow-neon-cyan);
    border: 1px solid var(--border-neon);
  }

  .logout-btn {
    color: #ff6b6b !important;
  }

  .logout-btn:hover {
    color: #ff5252 !important;
    background: rgba(255, 107, 107, 0.1) !important;
    box-shadow: 0 0 10px rgba(255, 107, 107, 0.3) !important;
  }

  @media (max-width: 800px) {
    .menu-toggle {
      display: block;
    }

    .nav-content {
      flex-direction: column;
      align-items: stretch;
      gap: 0.5rem;
      padding: 1rem;
    }

    .nav-brand {
      justify-content: space-between;
    }

    .nav-links {
      display: none;
      flex-direction: column;
      gap: 0.5rem;
      margin: 1rem 0;
      overflow-x: auto;
      max-width: 100vw;
      padding-bottom: 0.5rem;
    }

    .nav-links.open {
      display: flex;
    }

    .nav-link {
      width: 100%;
      padding: 1rem 0.75rem;
      font-size: 1.1rem;
      text-align: left;
      border-radius: 8px;
    }
  }
</style> 