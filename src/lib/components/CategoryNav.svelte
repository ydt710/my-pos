<script lang="ts">
  export let activeCategory: string = '';
  
  const categories = [
    { 
      id: 'joints', 
      name: 'Joints', 
      icon: '🌿',
      image: 'https://cdn-icons-png.flaticon.com/512/1021/1021001.png'
    },
    { 
      id: 'concentrate', 
      name: 'Concentrate', 
      icon: '💧',
      image: 'https://cdn-icons-png.flaticon.com/512/1021/1021002.png'
    },
    { 
      id: 'flower', 
      name: 'Flower', 
      icon: '🌸',
      image: 'https://cdn-icons-png.flaticon.com/512/1021/1021003.png'
    },
    { 
      id: 'edibles', 
      name: 'Edibles', 
      icon: '🍬',
      image: 'https://cdn-icons-png.flaticon.com/512/1021/1021004.png'
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
    >
      <div class="image-container">
        <img src={category.image} alt={category.name} class="category-image" />
        <span class="icon">{category.icon}</span>
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
    background: white;
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

  .category-button.active .icon {
    background: #007bff;
    color: white;
  }

  .image-container {
    position: relative;
    width: 60px;
    height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .category-image {
    width: 100%;
    height: 100%;
    object-fit: contain;
    filter: drop-shadow(0 2px 4px rgba(0,0,0,0.1));
    transition: transform 0.2s ease;
  }

  .category-button:hover .category-image {
    transform: scale(1.1);
  }

  .icon {
    position: absolute;
    bottom: -5px;
    right: -5px;
    background: white;
    border-radius: 50%;
    padding: 4px;
    font-size: 1.2rem;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    transition: all 0.2s ease;
  }

  .name {
    font-size: 1rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: color 0.2s ease;
  }

  @media (max-width: 768px) {
    .category-nav {
      flex-wrap: wrap;
      gap: 0.5rem;
      padding: 0.75rem;
      height: auto;
      min-height: 120px;
      align-content: flex-start;
    }

    .category-button {
      padding: 0.75rem;
      min-width: 80px;
      flex: 1 1 calc(50% - 0.5rem);
      max-width: calc(50% - 0.5rem);
    }

    .image-container {
      width: 40px;
      height: 40px;
    }

    .icon {
      font-size: 0.9rem;
      padding: 2px;
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
  }
</style> 