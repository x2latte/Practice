// Composables
import { createRouter, createWebHistory } from 'vue-router'
import { routes } from '@/router/routes.ts'
import { useUserStore } from '@/stores/user'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

router.beforeEach((to, _to) => {
  // проверка авторизации для защищенных страниц
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const store = useUserStore()
  if (requiresAuth && !store.accessToken) {
    return { name: 'login' }
  }
})

export default router
