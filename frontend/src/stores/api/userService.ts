import type { LoginType } from '@/stores/types/user_types'
import { httpClient } from '@/stores/api/base'
import { processError } from '@/stores/api/utils'

export default {
  async login (formData: LoginType) {
    try {
      const response = await httpClient.post('users/login', {
        username: formData.username,
        email: formData.username,
        password: formData.password
      })
      const accessToken = response.data.access_token
      const refreshToken = response.data.refresh_token
      const tokenType = response.data.token_type
      return { accessToken, tokenType, refreshToken }
    } catch (error) {
      throw processError(error)
    }
  },

  async register (name: string, email: string, login: string, password: string) {
    try {
      const response = await httpClient.post('users/register', {
        name,
        login,
        email,
        password,
      })
      const accessToken = response.data.access_token
      const refreshToken = response.data.refresh_token
      const tokenType = response.data.token_type
      return { accessToken, tokenType, refreshToken }
    } catch (error) {
      throw processError(error)
    }
  },

  async refreshToken (refreshToken: string) {
    try {
      const response = await httpClient.post('users/refresh', { refresh_token: refreshToken })
      return {
        accessToken: response.data.access_token,
        refreshToken: response.data.refresh_token,
      }
    } catch (error) {
      throw processError(error)
    }
  },

  async getProfile () {
    try {
      const response = await httpClient.get('users/me')
      return response.data
    } catch (error) {
      throw processError(error)
    }
  },

  async logout () {
    try {
      const response = await httpClient.post('users/logout')
      return response.data
    } catch (error) {
      throw processError(error)
    }
  },
}
