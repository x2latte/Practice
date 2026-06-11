import { fileURLToPath, URL } from 'node:url'
import Vue from '@vitejs/plugin-vue'
import Fonts from 'unplugin-fonts/vite'
import { defineConfig } from 'vite'
import Vuetify from 'vite-plugin-vuetify'

export default defineConfig({
  server: {
    port: 3000,
  },
  plugins: [
    Vue(),
    Vuetify({
      autoImport: true,
    }),
    Fonts({
      fontsource: {
        families: [{ name: 'Roboto', weights: [100,300,400,500,700,900] }],
      },
    }),
  ],
  define: { 'process.env': {} },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('src', import.meta.url)),
    },
    extensions: ['.js', '.json', '.jsx', '.mjs', '.ts', '.tsx', '.vue'],
  },
})
