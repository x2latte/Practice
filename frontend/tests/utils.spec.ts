import { describe, it, expect } from 'vitest'
import { processError, validators } from '@/stores/api/utils'

describe('Utils', () => {
  it('processError extracts message from response', () => {
    const error = { response: { data: { detail: 'Test error' }, status: 400 } }
    const result = processError(error)
    expect(result.message).toBe('Test error')
    expect(result.code).toBe(400)
  })

  it('validators work correctly', () => {
    expect(validators.required('')).toBe('Поле обязательно')
    expect(validators.required('test')).toBe(true)
    expect(validators.email('test@example.com')).toBe(true)
    expect(validators.email('invalid')).toBe('Введите корректный email')
  })
})
