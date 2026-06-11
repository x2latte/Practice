// Хранилище информации о проектах
import type { ProjectType } from '@/stores/types/project_types'

import { defineStore } from 'pinia'
import projectService from '@/stores/api/projectService'

export const useProjectsStore = defineStore('projects', {
  state: () => ({
    list: [] as ProjectType[],
    error: null,
  }),
  getters: {},
  actions: {
    /**
     * получение списка проектов
     */
    async getProjects () {
      this.error = null
      try {
        return await projectService.getProjects()
      } catch (error: any) {
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },

    /**
     * получение списка требований в проекте
     */
    async getRequirements (projectGuid: string) {
      this.error = null
      try {
        return await projectService.getRequirements(projectGuid)
      } catch (error: any) {
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },

    /**
     * Добавление проекта
     */
    async createProject (project: any) {
      this.error = null
      try {
        await projectService.createProject(project)
      } catch (error: any) {
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },

    /**
     * Добавление требования
     */
    async createRequirement (projectGuid: string, reqData: any) {
      this.error = null
      try {
        await projectService.createRequirement(projectGuid, reqData)
      } catch (error: any) {
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },

    async updateRequirement (reqId: string, reqData: any) {
      this.error = null
      try {
        await projectService.updateRequirement(reqId, reqData)
      } catch (error: any) {
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },

    async deleteRequirement (reqId: string) {
      this.error = null
      try {
        await projectService.deleteRequirement(reqId)
      } catch (error: any) {
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },
  },
})
