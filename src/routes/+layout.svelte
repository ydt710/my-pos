<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { onMount } from 'svelte';
	import Snackbar from '$lib/components/Snackbar.svelte';
	import { snackbarStore, showSnackbar } from '$lib/stores/snackbarStore';

	onMount(async () => {
		const { data: { user } } = await supabase.auth.getUser();
		if (user && user.user_metadata && user.user_metadata.is_admin === true) {
			supabase
				.channel('orders-changes')
				.on(
					'postgres_changes',
					{ event: 'INSERT', schema: 'public', table: 'orders' },
					(payload) => {
						showSnackbar('New order placed! Order ID: ' + payload.new.id);
					}
				)
				.subscribe();
		}
	});
</script>

<slot />
<Snackbar {...$snackbarStore} />

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
