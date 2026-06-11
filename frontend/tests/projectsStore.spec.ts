import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useProjectsStore } from '@/stores/projects'
import projectService from '@/stores/api/projectService'

vi.mock('@/stores/api/projectService', () => ({
  default: {
    getProjects: vi.fn(),
    createProject: vi.fn(),
    getRequirements: vi.fn(),
    createRequirement: vi.fn(),
    updateRequirement: vi.fn(),
    deleteRequirement: vi.fn(),
  }
}))

describe('Projects Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('fetches projects successfully', async () => {
    const mockProjects = [{ guid: '1', name: 'Test Project' }]
    projectService.getProjects.mockResolvedValue(mockProjects)

    const store = useProjectsStore()
    const result = await store.getProjects()

    expect(projectService.getProjects).toHaveBeenCalled()
    expect(result).toEqual(mockProjects)
  })

  it('handles errors on getProjects', async () => {
    projectService.getProjects.mockRejectedValue(new Error('Network error'))

    const store = useProjectsStore()
    await expect(store.getProjects()).rejects.toThrow('Network error')
    expect(store.error).toBe('Network error')
  })
})
