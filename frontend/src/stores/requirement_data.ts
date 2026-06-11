// Хранилище данных отдельного требования

import type { ExtendedRequirementType } from '@/stores/types/project_types.ts'
import { defineStore } from 'pinia'
import projectService from '@/stores/api/projectService.ts'

export function useRequirementDataStore (reqId: string) {
  return defineStore(`req-${reqId}`, {
    state: () => ({
      isLoading: false,
      isLoaded: false,
      data: {} as ExtendedRequirementType | null,
    }),
    getters: {},
    actions: {
      async loadData () {
        if (this.isLoading) {
          return
        }
        this.isLoading = true
        this.data = await projectService.getRequirementData(reqId)
        this.$state.isLoaded = true
        this.isLoading = false
      },
    },
  })
}
