// Types
import type { App } from 'vue'

// Plugins
import pinia from '@/plugins/pinia'
import vuetify from '@/plugins/vuetify'
import router from '@/router'

export function registerPlugins (app: App) {
  app.use(vuetify)
  app.use(pinia)
  app.use(router)
}
