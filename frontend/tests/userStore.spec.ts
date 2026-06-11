import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useUserStore } from '@/stores/user'
import userService from '@/stores/api/userService'

vi.mock('@/stores/api/userService', () => ({
  default: {
    login: vi.fn(),
    register: vi.fn(),
    getProfile: vi.fn(),
    logout: vi.fn(),
    refreshToken: vi.fn(),
  },
}))

describe('User Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('logs in successfully', async () => {
    const mockTokens = { accessToken: 'token', tokenType: 'Bearer', refreshToken: 'refresh' }
    const mockProfile = { name: 'Test', email: 'test@test.com', login: 'test', is_admin: false, created_at: '', updated_at: '' }
    userService.login.mockResolvedValue(mockTokens)
    userService.getProfile.mockResolvedValue(mockProfile)

    const store = useUserStore()
    await store.login({ username: 'test', password: 'pass' })

    expect(store.accessToken).toBe('token')
    expect(store.profile.name).toBe('Test')
  })

  it('handles login error', async () => {
    userService.login.mockRejectedValue(new Error('Invalid credentials'))
    const store = useUserStore()
    await expect(store.login({ username: 'test', password: 'wrong' })).rejects.toThrow()
    expect(store.error).toBe('Invalid credentials')
  })
})
