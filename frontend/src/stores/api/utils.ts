/** Validation */
export const validators = {
  email: (v: string) => {
    const pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return pattern.test(v) || 'Введите корректный email'
  },
  required: (v: any) => !!v || 'Поле обязательно',
  integer: (v: any, maxVal: number) => (!Number.isNaN(Number.parseInt(v)) && Number.isFinite(v) && v <= maxVal) || 'Введите корректное значение',
}

type Pair<T, K> = [T, K]
type Pairs<T, K> = Pair<T, K>[]

export class ConcurrencyHandler {
  callbacks: Pairs<() => void, (error: any) => void> = []
  public async execute (action: () => Promise<void>): Promise<void> {
    const promise = new Promise<void>((resolve, reject) => {
      const onSuccess = () => {
        resolve()
      }

      const onError = (error: any) => {
        reject(error)
      }

      this.callbacks.push([onSuccess, onError])
    })

    const performAction = this.callbacks.length === 1
    if (performAction) {
      try {
        await action()

        for (const c of this.callbacks) {
          c[0]()
        }
      } catch (error: any) {
        for (const c of this.callbacks) {
          c[1](error)
        }
      }

      this.callbacks = []
    }

    return promise
  }
}

export function processError (error: any) {
  if (error.response) {
    if (error.response.data.detail) {
      return ({ code: error.response.status, message: error.response.data.detail })
    }
    return ({ code: error.response.status, message: error.response.data })
  }
  if (error.request) {
    return ({ code: 0, message: error.request })
  }
  return ({ code: -1, message: error.message })
}
