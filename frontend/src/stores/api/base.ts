import axios, { type AxiosInstance, type AxiosRequestConfig } from 'axios'
import router from '@/router'
import { ConcurrencyHandler } from '@/stores/api/utils'
import { useUserStore } from '@/stores/user'

async function refToken () {
  const store = useUserStore()
  if (store) {
    return await store.refreshingToken()
  }
}

class Client {
  private httpClient: AxiosInstance
  private concurrencyHandler: ConcurrencyHandler

  constructor () {
    this.httpClient = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' })
    this.concurrencyHandler = new ConcurrencyHandler()

    this.httpClient.interceptors.request.use(config => {
      const store = useUserStore()
      const token = store.accessToken
      const token_type = store.tokenType
      if (token) {
        config.headers.Authorization = `${token_type} ${token}`
      }
      return config
    })

    this.httpClient.interceptors.response.use(response => response, error => {
      if (error.response && error.response.status === 401 && !error.config.url.endsWith('users/login')) {
        if (error.config.url.endsWith('users/refresh')) {
          router.push({ name: 'login' })
          return Promise.reject(error)
        }
        return this.concurrencyHandler.execute(refToken).then(() => {
          const store = useUserStore()
          error.config.headers['Authorization'] = `${store.tokenType} ${store.accessToken}`
          return axios.request(error.config)
        })
      }
      return Promise.reject(error)
    })
  }

  async post (url: string, data?: unknown, config?: AxiosRequestConfig) {
    return await this.httpClient.post(url, data, config)
  }

  async put (url: string, data?: unknown, config?: AxiosRequestConfig) {
    return await this.httpClient.put(url, data, config)
  }

  async delete (url: string, config?: AxiosRequestConfig) {
    return await this.httpClient.delete(url, config)
  }

  async get (url: string, config?: AxiosRequestConfig) {
    return await this.httpClient.get(url, config)
  }
}

export const httpClient = new Client()
