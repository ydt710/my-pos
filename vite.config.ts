import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		allowedHosts: [
			'af85-102-208-9-231.ngrok-free.app'
		],
		host: '0.0.0.0', // 👈 allows connections from your local network
		port: 5173 // or whichever port you want
	}
}); 