import { vi } from 'vitest'
import { config } from '@vue/test-utils'

// Заглушка localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => { store[key] = value },
    removeItem: (key: string) => { delete store[key] },
    clear: () => { store = {} },
    length: 0,
    key: vi.fn(),
  }
})()
global.localStorage = localStorageMock

// Мок vue-router
vi.mock('vue-router', () => ({
  useRouter: vi.fn(() => ({ push: vi.fn(), replace: vi.fn() })),
  useRoute: vi.fn(() => ({ params: {}, query: {} })),
  RouterLink: { template: '<a><slot /></a>' },
}))

// Мок httpClient
vi.mock('@/stores/api/base', () => ({
  httpClient: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}))

// Глобальные заглушки для Vuetify компонентов
config.global.stubs = {
  VApp: true,
  VMain: true,
  VContainer: true,
  VLayout: true,
  VCard: true,
  VCardTitle: true,
  VCardText: true,
  VCardActions: true,
  VCardItem: true,
  VTextField: true,
  VTextarea: true,
  VBtn: true,
  VAlert: true,
  VRow: true,
  VCol: true,
  VForm: true,
  VList: true,
  VListItem: true,
  VToolbar: true,
  VExpansionPanels: true,
  VExpansionPanel: true,
  VProgressLinear: true,
  VMenu: true,
  VAvatar: true,
  VDivider: true,
  VSelect: true,
  VSwitch: true,
  VDataTable: true,
  VIcon: true,
  VDialog: true,
  VWindow: true,
  VWindowItem: true,
  VTabs: true,
  VTab: true,
  RouterLink: true,
}
