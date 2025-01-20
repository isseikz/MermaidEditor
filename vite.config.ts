import { defineConfig } from "vitest/config";
import { sveltekit } from '@sveltejs/kit/vite';

export default defineConfig({
    plugins: [sveltekit()],
    base: 'MermaidEditor',
    test: {
        include: ['src/**/*.{test,spec}.{js,ts}'],
        setupFiles: ['./src/test/setupTest.ts']
    }
});
