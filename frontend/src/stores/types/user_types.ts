// используемые типы для работы с аккаунтами

// структура данных авторизации
export type LoginType = {
  username: string
  password: string
}

// структура данных профиля
export type ProfileType = {
  name: string
  email: string
  login: string
  is_admin: boolean
  created_at: Date
  updated_at: Date
}
