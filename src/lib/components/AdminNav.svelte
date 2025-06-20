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

<nav class="admin-nav">
  <div class="nav-content">
    <div class="nav-brand">
      <button class="menu-toggle" on:click={() => menuOpen = !menuOpen} aria-label="Toggle menu">
        ☰
      </button>
      <span class="brand-text">Admin Dashboard</span>
    </div>

    <div class="nav-links" class:open={menuOpen}>
      <a 
        href="/"
        class="nav-link" 
        class:active={$page.url.pathname === '/'}
        on:click={() => menuOpen = false}
      >
        Home
      </a>
      <a 
        href="/admin"
        class="nav-link" 
        class:active={$page.url.pathname === '/admin'}
        on:click={() => menuOpen = false}
      >
        Dashboard
      </a>
      <a 
        href="/admin/products"
        class="nav-link" 
        class:active={$page.url.pathname === '/admin/products'}
        on:click={() => menuOpen = false}
      >
        Products
      </a>
      <a 
        href="/admin/orders"
        class="nav-link" 
        class:active={$page.url.pathname === '/admin/orders'}
        on:click={() => menuOpen = false}
      >
        Orders
      </a>
      <a 
        href="/admin/users"
        class="nav-link" 
        class:active={$page.url.pathname === '/admin/users'}
        on:click={() => menuOpen = false}
      >
        Users
      </a>
      <a 
        href="/admin/settings"
        class="nav-link" 
        class:active={$page.url.pathname === '/admin/settings'}
        on:click={() => menuOpen = false}
      >
        Settings
      </a>
      <a 
        href="/admin/stock-management"
        class="nav-link" 
        class:active={$page.url.pathname === '/admin/stock-management'}
        on:click={() => menuOpen = false}
      >
        Stock
      </a>
    </div>
  </div>
</nav>

<style>
  .admin-nav {
    background: #1a1a1a;
    color: white;
  
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
  }

  .nav-content {
    max-width: 1400px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    justify-content: space-between;
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
    background: none;
    border: none;
    color: white;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0.5rem;
  }

  .nav-links {
    display: flex;
    align-items: center;
    gap: 1.5rem;
  }

  .nav-link {
    color: #ccc;
    text-decoration: none;
    padding: 0.5rem;
    border-radius: 4px;
    transition: color 0.2s, background-color 0.2s;
    background: none;
    border: none;
    font-size: inherit;
    cursor: pointer;
    display: inline-block;
  }

  .nav-link:hover {
    color: white;
    background: rgba(255, 255, 255, 0.1);
  }

  .nav-link.active {
    color: white;
    background: rgba(255, 255, 255, 0.15);
  }

  @media (max-width: 800px) {
    .menu-toggle {
      display: block;
    }

    .nav-content {
      flex-direction: column;
      align-items: stretch;
      gap: 0.5rem;
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
      min-width: 120px;
      text-align: left;
    }
  }
</style> 