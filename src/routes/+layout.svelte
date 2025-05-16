<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { onMount } from 'svelte';
	import Snackbar from '$lib/components/Snackbar.svelte';
	import { snackbarStore, showSnackbar } from '$lib/stores/snackbarStore';
	import '../styles/global.css';
	import { fade, scale } from 'svelte/transition';

	let showAgeModal = false;

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

		if (typeof localStorage !== 'undefined' && !localStorage.getItem('ageConfirmed')) {
			showAgeModal = true;
		}
	});

	function confirmAge() {
		localStorage.setItem('ageConfirmed', 'true');
		showAgeModal = false;
	}
</script>

{#if showAgeModal}
	<div class="age-modal-backdrop">
		<div class="age-modal" in:scale={{ duration: 250 }} out:fade={{ duration: 200 }}>
			<h2>Age Verification</h2>
			<p>You must be 18 years or older to enter this site.</p>
			<button class="confirm-btn" on:click={confirmAge}>I am 18 or older</button>
		</div>
	</div>
{/if}

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

	.age-modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.85);
		z-index: 9999;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.age-modal {
		background: #fff;
		color: #222;
		padding: 2.5rem 2rem;
		border-radius: 16px;
		box-shadow: 0 8px 32px rgba(0,0,0,0.25);
		text-align: center;
		max-width: 90vw;
		min-width: 320px;
	}
	.age-modal h2 {
		margin-bottom: 1rem;
		font-size: 2rem;
	}
	.age-modal p {
		margin-bottom: 2rem;
		font-size: 1.1rem;
	}
	.confirm-btn {
		background: #007bff;
		color: #fff;
		border: none;
		border-radius: 8px;
		padding: 0.75rem 2rem;
		font-size: 1.1rem;
		cursor: pointer;
		transition: background 0.2s;
	}
	.confirm-btn:hover {
		background: #0056b3;
	}
</style>
