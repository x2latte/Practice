<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { httpClient } from '@/stores/api/base'
import type { MemberType, UserType } from '@/stores/types/project_types'

const route = useRoute()
const projectGuid = route.params.projectGuid as string
const members = ref<MemberType[]>([])
const searchUser = ref('')
const selectedUser = ref<UserType | null>(null)
const selectedRole = ref('member')
const userSearchResults = ref<UserType[]>([])

async function loadMembers() {
  const resp = await httpClient.get(`projects/${projectGuid}/users`)
  members.value = resp.data
}

async function addMember() {
  if (!selectedUser.value) return
  await httpClient.post(`projects/${projectGuid}/users`, {
    user_guid: selectedUser.value.guid,
    role: selectedRole.value
  })
  await loadMembers()
  selectedUser.value = null
  searchUser.value = ''
}

async function updateRole(userGuid: string, newRole: string) {
  await httpClient.put(`projects/${projectGuid}/users/${userGuid}`, { role: newRole })
  await loadMembers()
}

async function removeMember(userGuid: string) {
  if (confirm('Удалить участника?')) {
    await httpClient.delete(`projects/${projectGuid}/users/${userGuid}`)
    await loadMembers()
  }
}

async function searchUsers() {
  if (searchUser.value.length < 3) {
    userSearchResults.value = []
    return
  }
  const resp = await httpClient.get(`users?name=${searchUser.value}`)
  userSearchResults.value = resp.data
}

onMounted(loadMembers)
</script>

<template>
  <v-toolbar title="Участники проекта"></v-toolbar>
  <v-row>
    <v-col cols="6">
      <v-autocomplete 
        v-model="selectedUser" 
        :items="userSearchResults" 
        item-title="name" 
        item-value="guid" 
        label="Поиск пользователя" 
        clearable
        @update:search="searchUsers"
      ></v-autocomplete>
    </v-col>
    <v-col cols="3"><v-select v-model="selectedRole" :items="['owner','member','reader']" label="Роль"></v-select></v-col>
    <v-col cols="3"><v-btn @click="addMember">Добавить</v-btn></v-col>
  </v-row>
  <v-table>
    <thead>
      <tr><th>Имя</th><th>Роль</th><th>Действия</th></tr>
    </thead>
    <tbody>
      <tr v-for="m in members" :key="m.id">
        <td>{{ m.user_name }}</td>
        <td><v-select :model-value="m.role" :items="['owner','member','reader']" @update:model-value="updateRole(m.user_guid, $event)"></v-select></td>
        <td><v-btn icon="mdi-delete" @click="removeMember(m.user_guid)"></v-btn></td>
      </tr>
    </tbody>
  </v-table>
</template>
