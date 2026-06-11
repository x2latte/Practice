import Vue from '@vitejs/plugin-vue';
import Fonts from 'unplugin-fonts/vite';
import Vuetify from 'vite-plugin-vuetify';
import path from 'path';
import { defineConfig } from 'vite';

export default defineConfig(() => {
  return {
    plugins: [
      Vue(),
      Vuetify({
        autoImport: true,
      }),
      Fonts({
        fontsource: {
          families: [{ name: 'Roboto', weights: [100, 300, 400, 500, 700, 900] }],
        },
      }),
    ],
    define: { 'process.env': {} },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './frontend/src'),
      },
      extensions: ['.js', '.json', '.jsx', '.mjs', '.ts', '.tsx', '.vue'],
    },
    server: {
      port: 3000,
      // HMR is disabled in AI Studio via DISABLE_HMR env var.
      hmr: process.env.DISABLE_HMR !== 'true',
      watch: process.env.DISABLE_HMR === 'true' ? null : {},
    },
  };
});
