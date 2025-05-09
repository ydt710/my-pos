<script lang="ts">
	
	import { supabase } from '$lib/supabase';

	let { children } = $props();
</script>

<div class="layout">
	{@render children()}
</div>

<style>
	.layout {
		min-height: 100vh;
		position: relative;
		background-color: #f8f9fa;
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
