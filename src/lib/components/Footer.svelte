<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { getCachedSettings, cacheSettings } from '$lib/services/cacheService';

  interface BusinessHours {
    [key: string]: string;
    monday: string;
    tuesday: string;
    wednesday: string;
    thursday: string;
    friday: string;
    saturday: string;
    sunday: string;
  }

  interface Settings {
    store_name?: string;
    store_email?: string;
    store_phone?: string;
    store_address?: string;
    business_hours?: BusinessHours | string;
    facebook_url?: string;
    instagram_url?: string;
    twitter_url?: string;
  }

  let settings: Settings | null = null;
  let loading = true;

  onMount(async () => {
    loading = true;
    try {
      const cached = getCachedSettings();
      if (cached) {
        settings = cached;
      } else {
        const { data, error } = await supabase
          .from('settings')
          .select('store_name, store_email, store_phone, store_address, business_hours, facebook_url, instagram_url, twitter_url')
          .limit(1)
          .maybeSingle();

        if (error) throw error;
        
        if (data) {
          if (typeof data.business_hours === 'string') {
            try {
              data.business_hours = JSON.parse(data.business_hours);
            } catch (e) {
              console.error('Error parsing business_hours:', e);
            }
          }
          settings = data;
          cacheSettings(data); // Cache the newly fetched settings
        }
      }
    } catch (err) {
      console.error('Error loading store settings for footer:', err);
    } finally {
      loading = false;
    }
  });

  const daysOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  $: sortedBusinessHours = settings?.business_hours && typeof settings.business_hours !== 'string' 
    ? Object.entries(settings.business_hours).sort(([dayA], [dayB]) => daysOrder.indexOf(dayA) - daysOrder.indexOf(dayB))
    : [];

</script>

{#if !loading && settings}
  <footer class="store-footer">
    <div class="footer-content">
      <div class="store-details">
        <h3>{settings.store_name || 'Our Store'}</h3>
        <p>{settings.store_address || ''}</p>
        <p>
          {#if settings.store_email}
            <a href="mailto:{settings.store_email}">{settings.store_email}</a>
          {/if}
          {#if settings.store_email && settings.store_phone} | {/if}
          {#if settings.store_phone}
            <a href="tel:{settings.store_phone}">{settings.store_phone}</a>
          {/if}
        </p>
      </div>
      <div class="business-hours">
        <h3>Opening Hours</h3>
        <ul>
          {#each sortedBusinessHours as [day, hours]}
            <li>
              <span class="day">{day.charAt(0).toUpperCase() + day.slice(1)}</span>
              <span class="hours">{hours}</span>
            </li>
          {/each}
        </ul>
      </div>
      <div class="social-media">
        <h3>Follow Us</h3>
        <div class="social-links">
          {#if settings.facebook_url}
            <a href={settings.facebook_url} target="_blank" rel="noopener noreferrer" aria-label="Follow us on Facebook">
              <i class="fab fa-facebook-f"></i>
            </a>
          {/if}
          {#if settings.instagram_url}
            <a href={settings.instagram_url} target="_blank" rel="noopener noreferrer" aria-label="Follow us on Instagram">
              <i class="fab fa-instagram"></i>
            </a>
          {/if}
          {#if settings.twitter_url}
            <a href={settings.twitter_url} target="_blank" rel="noopener noreferrer" aria-label="Follow us on Twitter">
              <i class="fab fa-twitter"></i>
            </a>
          {/if}
        </div>
      </div>
    </div>
    <div class="footer-bottom">
      &copy; {new Date().getFullYear()} {settings.store_name || 'Route 420'}. All Rights Reserved.
    </div>
  </footer>
{/if}

<style>
.store-footer {
    
    backdrop-filter: blur(10px);
    color: #cbd5e1;
    
    margin-top: 4rem;
    
    font-size: 0.9rem;
    width: 100%;
}

.footer-content {
    display: flex;
    justify-content: space-around;
    flex-wrap: wrap;
    gap: 2rem;
    max-width: 1200px;
    margin: 0 auto 2rem;
}

.store-details, .business-hours, .social-media {
    flex: 1;
    min-width: 280px;
    text-align: center;
}

h3 {
    color: #fff;
    font-size: 1.25rem;
    margin-bottom: 1rem;
    font-weight: 600;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
    padding-bottom: 0.5rem;
}

.store-details p {
    margin: 0.5rem 0;
    line-height: 1.6;
}

.store-details a {
    color: #93c5fd;
    text-decoration: none;
    transition: color 0.2s;
}

.store-details a:hover {
    color: #bfdbfe;
    text-decoration: underline;
}

.business-hours ul {
    list-style: none;
    padding: 0;
    margin: 0;
}

.business-hours li {
    display: flex;
    justify-content: space-between;
    padding: 0.4rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
}

.business-hours .day {
    font-weight: 500;
}

.business-hours .hours {
    color: #94a3b8;
}

.footer-bottom {
    text-align: center;
    margin-top: 2rem;
    padding-top: 1.5rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    color: #94a3b8;
    font-size: 0.8rem;
}

.social-media {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.social-links {
  display: flex;
  gap: 1.5rem;
  justify-content: center;
  margin-top: 0.5rem;
}

.social-links a {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 45px;
  height: 45px;
  background: linear-gradient(135deg, #00f2fe, #4facfe);
  color: white;
  border-radius: 50%;
  text-decoration: none;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(0, 242, 254, 0.2);
}

.social-links a:hover {
  transform: translateY(-3px) scale(1.1);
  box-shadow: 0 8px 20px rgba(0, 242, 254, 0.4);
  background: linear-gradient(135deg, #00deff, #39a9fe);
}

.social-links a i {
  font-size: 1.2rem;
}

@media (max-width: 768px) {
  .footer-content {
    flex-direction: column;
    align-items: center;
  }
  
  .social-links {
    gap: 1rem;
  }
  
  .social-links a {
    width: 40px;
    height: 40px;
  }
  
  .social-links a i {
    font-size: 1rem;
  }
}
</style> 