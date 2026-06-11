// Хранилище данных о конкретном проекте

import type { ExtendedProjectType, ProjectStatsType } from '@/stores/types/project_types.ts'
import { defineStore } from 'pinia'
import projectService from '@/stores/api/projectService.ts'

export function useProjectDataStore (projectGuid: string) {
  return defineStore(`project-${projectGuid}`, {
    state: () => ({
      isLoading: false,
      isLoaded: false,
      data: {} as ExtendedProjectType | null,
      statsData: {} as ProjectStatsType | null,
    }),
    getters: {},
    actions: {
      async loadData () {
        if (this.isLoading) {
          return
        }
        this.isLoading = true
        this.data = await projectService.getProjectData(projectGuid)
        this.$state.isLoaded = true
        this.isLoading = false
      },

      /**
       * Обновление свойства проекта
       * @param propName имя свойства
       * @param value новое значение
       */
      async updateVal (propName: string, value: string) {
        this.data = await projectService.updateProjectVal(projectGuid, propName, value)
      },

      async loadStats () {
        this.statsData = await projectService.getProjectStats(projectGuid)
      },
    },
  })
}
