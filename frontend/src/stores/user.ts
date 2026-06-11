import type { LoginType, ProfileType } from '@/stores/types/user_types'
import { defineStore } from 'pinia'
import userService from '@/stores/api/userService'

export const useUserStore = defineStore('user', {
  state: () => ({
    profile: {} as ProfileType,
    accessToken: localStorage.getItem('accessToken') || null,
    tokenType: localStorage.getItem('tokenType') || 'Bearer',
    refreshToken: localStorage.getItem('refreshToken') || null,
    refreshingCall: null,
    error: null,
    prevPageVal: null,
  }),
  persist: {
    storage: localStorage,
    pick: ['accessToken', 'tokenType', 'refreshToken', 'profile'],
  },
  getters: {
    initials: state => {
      if (state.profile.hasOwnProperty('name')) {
        return state.profile.name.split(' ').map(n => n[0]).join('.') + '.'
      }
      return ''
    },
    hasError: state => !!state.error,
    prevPage: state => state.prevPageVal || '/',
  },
  actions: {
    async login (formData: LoginType) {
      // авторизация пользователя и если все ок, то сохранение токена
      try {
        const { accessToken, tokenType, refreshToken } = await userService.login(formData)
        this.accessToken = accessToken
        this.tokenType = tokenType
        this.refreshToken = refreshToken
        this.profile = await userService.getProfile()
      } catch (error: any) {
        this.refreshToken = null
        this.accessToken = null
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },
    async register (name: string, email: string, login: string, password: string) {
      try {
        const {
          accessToken,
          tokenType,
          refreshToken,
        } = await userService.register(name, email, login, password)
        this.accessToken = accessToken
        this.tokenType = tokenType
        this.refreshToken = refreshToken
        this.profile = await userService.getProfile()
      } catch (error: any) {
        this.refreshToken = null
        this.accessToken = null
        this.error = error.message || 'Произошла ошибка'
        throw error
      }
    },
    async logout () {
      userService.logout().then(() => {
        this.accessToken = null
        this.refreshToken = null
        this.profile = {} as ProfileType
        this.error = null
      },
      error => {
        this.error = error
        this.accessToken = null
        this.refreshToken = null
        this.profile = {} as ProfileType
      })
    },
    async refreshingToken () {
      if (this.refreshToken === null) {
        throw new Error('Refresh token not found')
      } else {
        this.accessToken = await userService.refreshToken(this.refreshToken)
        this.refreshingCall = null
      }
    },
  },
})
