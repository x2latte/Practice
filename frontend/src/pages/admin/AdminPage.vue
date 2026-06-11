<template>
  <v-container>
    <v-text-field v-model="search" label="Поиск" clearable />
    <v-data-table :headers="headers" :items="filteredUsers" :loading="loading">
      <template #item.actions="{ item }">
        <v-btn @click="toggleAdmin(item)">Админ</v-btn>
        <v-btn @click="toggleActive(item)">{{ item.is_active ? 'Блок' : 'Разблок' }}</v-btn>
        <v-btn color="error" @click="deleteUser(item)">Удалить</v-btn>
      </template>
    </v-data-table>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { httpClient } from '@/stores/api/base'
import type { UserType } from '@/stores/types/project_types'

const users = ref<UserType[]>([])
const search = ref('')
const loading = ref(false)

const headers = [
  { title: 'Имя', key: 'name' },
  { title: 'Логин', key: 'login' },
  { title: 'Email', key: 'email' },
  { title: 'Статус', key: 'is_active' },
  { title: 'Админ', key: 'is_admin' },
  { title: 'Действия', key: 'actions' }
]

const filteredUsers = computed(() => {
  if (!search.value) return users.value
  const s = search.value.toLowerCase()
  return users.value.filter(u => 
    u.name.toLowerCase().includes(s) || 
    u.login.toLowerCase().includes(s) ||
    u.email.toLowerCase().includes(s)
  )
})

async function load() {
  loading.value = true
  try {
    const res = await httpClient.get('users/all')
    users.value = res.data
  } catch (e) {
    console.error('Failed to load users', e)
  } finally {
    loading.value = false
  }
}

async function toggleAdmin(user: UserType) {
  await httpClient.put(`users/${user.guid}`, { is_admin: !user.is_admin })
  await load()
}

async function toggleActive(user: UserType) {
  await httpClient.put(`users/${user.guid}`, { is_active: !user.is_active })
  await load()
}

async function deleteUser(user: UserType) {
  if (confirm('Удалить пользователя?')) {
    await httpClient.delete(`users/${user.guid}`)
    await load()
  }
}

onMounted(load)
</script>
