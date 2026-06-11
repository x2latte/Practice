<template>
  <v-card class="ma-2" title="User Stories">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    
    <v-list v-if="items.length > 0">
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title class="font-weight-bold">
          Как {{ item.title }} я хочу {{ item.want }}, чтобы {{ item.so_that }}
        </v-list-item-title>
        <div class="text-caption text-grey mt-1" v-if="item.criteria">
          <strong>Критерии приемки:</strong> {{ item.criteria }}
        </div>
        
        <template #append>
          <v-btn icon="mdi-pencil" variant="text" @click="editItem(item)" />
          <v-btn icon="mdi-delete" variant="text" color="error" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-card-text v-else class="text-center text-grey">
      User Stories не заданы. Нажмите "+" чтобы добавить.
    </v-card-text>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать User Story' : 'Добавить User Story' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.title" label="Роль (Как... например, Покупатель)" />
          <v-text-field v-model="form.want" label="Действие (я хочу... например, оплатить картой онлайн)" />
          <v-text-field v-model="form.so_that" label="Цель (чтобы... например, не тратить время на кассе)" />
          <v-textarea v-model="form.criteria" label="Критерии приемки (Acceptance Criteria)" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">Отмена</v-btn>
          <v-btn color="primary" @click="save">Сохранить</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-card>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { httpClient } from '@/stores/api/base'

const props = defineProps({ projectGuid: String })
const items = ref([])
const dialog = ref(false)
const editing = ref(false)
const form = ref({ title: '', want: '', so_that: '', criteria: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/user-stories`)
  items.value = res.data
}

const openDialog = () => {
  form.value = { title: '', want: '', so_that: '', criteria: '' }
  editing.value = false
  dialog.value = true
}

const editItem = (item) => {
  form.value = { ...item }
  currentId.value = item.id
  editing.value = true
  dialog.value = true
}

const save = async () => {
  if (editing.value) {
    await httpClient.put(`projects/${props.projectGuid}/user-stories/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/user-stories`, form.value)
  }
  await load()
  dialog.value = false
}

const deleteItem = async (id) => {
  if (confirm('Удалить эту User Story?')) {
    await httpClient.delete(`projects/${props.projectGuid}/user-stories/${id}`)
    await load()
  }
}

onMounted(load)
</script>
