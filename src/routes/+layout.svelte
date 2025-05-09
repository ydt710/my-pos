<script lang="ts">
	import { supabase } from '$lib/supabase';
</script>

<slot />

<style>
	:global(body) {
		margin: 0;
		padding: 0;
		overflow-x: hidden;
		background-color: #f8f9fa;
		min-height: 100vh;
	}

	:global(*) {
		position: relative;
		z-index: 1;
	}
</style>
