<template>
  <v-card class="ma-2" title="Бизнес-цели">
    <template #append>
      <v-btn icon="mdi-plus" @click="addGoal" />
    </template>
    <v-list>
      <v-list-item v-for="goal in goals" :key="goal.id">
        <v-text-field v-model="goal.description" @blur="updateGoal(goal)" />
        <template #append>
          <v-btn icon="mdi-delete" @click="deleteGoal(goal.id)" />
        </template>
      </v-list-item>
    </v-list>
  </v-card>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { httpClient } from '@/stores/api/base'

const props = defineProps({ projectGuid: String })
const goals = ref([])

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/business-goals`)
  goals.value = res.data
}

const addGoal = async () => {
  await httpClient.post(`projects/${props.projectGuid}/business-goals`, { description: 'Новая цель' })
  load()
}

const updateGoal = async (goal) => {
  await httpClient.put(`projects/${props.projectGuid}/business-goals/${goal.id}`, { description: goal.description })
}

const deleteGoal = async (id) => {
  await httpClient.delete(`projects/${props.projectGuid}/business-goals/${id}`)
  load()
}

onMounted(load)
</script>
