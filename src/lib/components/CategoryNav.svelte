<script lang="ts">
  export let activeCategory: string = '';
  
  const categories = [
    { 
      id: 'joints', 
      name: 'Joints', 
      icon: 'fa-joint'
    },
    { 
      id: 'concentrate', 
      name: 'Extracts',
      icon: 'fa-vial'
    },
    { 
      id: 'flower', 
      name: 'Flower', 
      icon: 'fa-cannabis'
    },
    { 
      id: 'edibles', 
      name: 'Edibles', 
      icon: 'fa-cookie'
    },
    { 
      id: 'headshop', 
      name: 'Headshop', 
      icon: 'fa-store' 
    }
  ];

  function handleCategoryClick(categoryId: string) {
    // Toggle the category if it's already active
    activeCategory = activeCategory === categoryId ? '' : categoryId;
  }
</script>

<div class="category-nav">
  {#each categories as category}
    <button 
      class="category-button {activeCategory === category.id ? 'active' : ''}"
      on:click={() => handleCategoryClick(category.id)}
      on:keydown={(e) => e.key === 'Enter' && handleCategoryClick(category.id)}
      role="tab"
      aria-selected={activeCategory === category.id}
      aria-controls={`category-${category.id}`}
      data-category={category.id}
    >
      <div class="image-container">
        <i class="fa-solid {category.icon}"></i>
      </div>
      <span class="name">{category.name}</span>
    </button>
  {/each}
</div>

<style>
  .category-nav {
    display: flex;
    justify-content: center;
    gap: 1.5rem;
    padding: 1.5rem;
    margin-bottom: 2rem;
    user-select: none;
    position: fixed;
    top: 60px;
    left: 0;
    right: 0;
    z-index: 5;
  }

  .category-button {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
    padding: 1.25rem;
    border: 2px solid transparent;
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    min-width: 120px;
    outline: none;
  }

  .category-button:hover {
    transform: translateY(-3px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    border-color: #007bff;
  }

  .category-button:focus {
    border-color: #007bff;
    box-shadow: 0 0 0 3px rgba(0,123,255,0.25);
  }

  .category-button.active {
    background: #007bff;
    color: white;
    border-color: #007bff;
    transform: translateY(-3px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  }

  .image-container {
    position: relative;
    width: 60px;
    height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .image-container i {
    font-size: 2rem;
    transition: transform 0.2s ease;
  }

  .category-button:hover .image-container i {
    transform: scale(1.1);
  }

  .name {
    font-size: 1rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: color 0.2s ease;
  }

  .category-button[data-category='concentrate'] .name {
    font-size: 0.9rem;
  }

  @media (max-width: 768px) {
    .category-nav {
      flex-wrap: wrap;
      gap: 0.5rem;
      height: auto;
      min-height: 120px;
      align-content: flex-start;
      justify-content: flex-start;
    }

    .category-button {
      padding: 0.75rem;
      min-width: 0;
      flex: 1 1 calc(33.333% - 0.5rem);
      max-width: calc(33.333% - 0.5rem);
    }

    .image-container {
      width: 40px;
      height: 40px;
    }

    .image-container i {
      font-size: 1.5rem;
    }

    .name {
      font-size: 0.8rem;
    }
  }

  @media (max-width: 480px) {
    .category-nav {
      min-height: 140px;
    }

    .category-button {
      padding: 0.5rem;
      min-width: 70px;
    }

    .image-container {
      width: 35px;
      height: 35px;
    }

    .image-container i {
      font-size: 1.25rem;
    }
  }
</style> 