<script lang="ts">
	import '../app.css';
	import { supabase } from '$lib/supabase';

	let { children } = $props();

	// Get the public URL for the logo
	let logoUrl = '';
	try {
		const { data } = supabase.storage.from('route420').getPublicUrl('logo.png');
		logoUrl = data.publicUrl;
	} catch (err) {
		console.error('Error getting logo URL:', err);
	}
</script>

<div class="layout" style="--logo-url: url('{logoUrl}')">
	{@render children()}
</div>

<style>
	.layout {
		min-height: 100vh;
		position: relative;
		background-color: #f8f9fa;
	}

	.layout::before {
		content: '';
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background-image: var(--logo-url);
		background-repeat: no-repeat;
		background-position: center;
		background-size: 50%;
		opacity: 0.1;
		z-index: 0;
		pointer-events: none;
	}

	:global(body) {
		margin: 0;
		padding: 0;
		overflow-x: hidden;
	}

	:global(*) {
		position: relative;
		z-index: 1;
	}
</style>
