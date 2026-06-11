// API для работы с проектами

import type { ExtendedProjectType, ExtendedRequirementType, ProjectStatsType } from '@/stores/types/project_types.ts'
import { httpClient } from '@/stores/api/base'
import { processError } from '@/stores/api/utils'

export default {
  async getProjects () {
    try {
      const ret = await httpClient.get('projects')
      return ret.data
    } catch (error) {
      throw processError(error)
    }
  },

  /**
   * Создание проекта
   */
  async createProject (data: any) {
    try {
      return await httpClient.post('projects', data)
    } catch (error) {
      throw processError(error)
    }
  },

  async getProjectData (projectGuid: string) {
    try {
      const ret = await httpClient.get(`projects/${projectGuid}`)
      return ret.data as ExtendedProjectType
    } catch (error) {
      throw processError(error)
    }
  },

  /**
   * Обновление свойства проекта
   */
  async updateProjectVal (projectGuid: string, propName: string, value: string) {
    try {
      const ret = await httpClient.put(`projects/${projectGuid}`, { [propName]: value })
      return ret.data as ExtendedProjectType
    } catch (error) {
      throw processError(error)
    }
  },

  /**
   * Получение детальных статистик по проекту
   */
  async getProjectStats (projectGuid: string) {
    try {
      const ret = await httpClient.get(`projects/${projectGuid}/stats`)
      return ret.data as ProjectStatsType
    } catch (error) {
      throw processError(error)
    }
  },

  /**
   * Создание требования в проекте
   */
  async createRequirement (projectGuid: string, data: any) {
    try {
      return await httpClient.post(`projects/${projectGuid}/requirements`, data)
    } catch (error) {
      throw processError(error)
    }
  },

  async updateRequirement (reqId: string, data: any) {
    try {
      return await httpClient.put(`requirements/${reqId}/`, data)
    } catch (error) {
      throw processError(error)
    }
  },

  async deleteRequirement (reqId: string) {
    try {
      return await httpClient.delete(`requirements/${reqId}/`)
    } catch (error) {
      throw processError(error)
    }
  },

  /**
   * получение списка требований к проекту
   */
  async getRequirements (projectGuid: string) {
    try {
      const ret = await httpClient.get(`projects/${projectGuid}/requirements`)
      return ret.data
    } catch (error) {
      throw processError(error)
    }
  },

  /**
   * Получение данных конкретного требования
   * @param reqId
   */
  async getRequirementData (reqId: string) {
    try {
      const ret = await httpClient.get(`requirements/${reqId}`)
      return ret.data as ExtendedRequirementType
    } catch (error) {
      throw processError(error)
    }
  },
}
