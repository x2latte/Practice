import EmptyLayout from '@/layouts/EmptyLayout.vue'
import ProjectLayout from '@/layouts/ProjectLayout.vue'
import ToolbarLayout from '@/layouts/ToolbarLayout.vue'

export const routes = [
  {
    path: '/',
    redirect: '/projects',
    name: 'root',
  },
  {
    path: '/',
    component: EmptyLayout,
    children: [
      {
        path: '/login',
        name: 'login',
        component: () => import('@/pages/account/LoginPage.vue'),
      },
      {
        path: '/signup',
        name: 'signup',
        component: () => import('@/pages/account/RegisterPage.vue'),
      },
      {
        path: '/password-recovery',
        name: 'recover-password',
        component: () => import('@/pages/account/RecoverPasswordPage.vue'),
      },
    ],
  },
  {
    path: '/',
    component: ToolbarLayout,
    children: [
      {
        path: '/projects',
        name: 'projects',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/ProjectsPage.vue'),
      },
      {
        path: '/projects/create',
        name: 'projects.create',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/CreatePage.vue'),
      },
      {
        path: '/profile',
        meta: { requiresAuth: true },
        name: 'profile',
        component: () => import('@/pages/account/ProfilePage.vue'),
      },
      {
        path: '/about',
        component: () => import('@/pages/AboutPage.vue'),
      },
      {
        path: '/admin',
        name: 'admin',
        meta: { requiresAuth: true },
        component: () => import('@/pages/admin/AdminPage.vue'),
      },
    ],
  },
  {
    path: '/',
    component: ProjectLayout,
    children: [
      {
        path: '/project/:projectGuid',
        name: 'project.dashboard',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/DashboardPage.vue'),
      },
      {
        path: '/project/:projectGuid/about',
        name: 'project.about',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/AboutPage.vue'),
      },
      {
        path: '/project/:projectGuid/requirements',
        name: 'project.requirements',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/RequirementsPage.vue'),
      },
      {
        path: '/project/:projectGuid/files',
        name: 'project.files',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/FilesPage.vue'),
      },
      {
        path: '/project/:projectGuid/members',
        name: 'project.members',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/MembersPage.vue'),
      },
      {
        path: '/project/:projectGuid/diagram',
        name: 'project.diagram',
        meta: { requiresAuth: true },
        component: () => import('@/pages/project/DiagramPage.vue'),
      },
    ],
  },
  {
    path: '/:catchAll(.*)',
    component: () => import('@/pages/NotFoundPage.vue'),
  },
]
