import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// `npm run dev` serves the UI on :5173 and sends API calls to the Studio backend (tools/studio/app.py on :8765).
const backend = 'http://127.0.0.1:8765'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': path.resolve(__dirname, './src') } },
  server: {
    proxy: { '/api': backend, '/img': backend, '/cover': backend, '/classic': backend, '/docs': backend },
  },
  build: { outDir: 'dist', emptyOutDir: true, chunkSizeWarningLimit: 800 },
})
