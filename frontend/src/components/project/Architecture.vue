<template>
  <v-card class="ma-2" title="Высокоуровневая архитектура системы">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    
    <v-list v-if="items.length > 0">
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title class="font-weight-bold">{{ item.title }}</v-list-item-title>
        <v-list-item-subtitle v-if="item.platform"><strong>Стек / Платформа:</strong> {{ item.platform }}</v-list-item-subtitle>
        <div class="text-body-2 mt-1">{{ item.content }}</div>
        
        <template #append>
          <v-btn icon="mdi-pencil" variant="text" @click="editItem(item)" />
          <v-btn icon="mdi-delete" variant="text" color="error" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-card-text v-else class="text-center text-grey">
      Архитектурные компоненты не описаны. Нажмите "+" чтобы добавить.
    </v-card-text>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать архитектурную запись' : 'Добавить архитектурную запись' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.title" label="Компонент архитектуры (например, Бэкенд-сервис)" />
          <v-text-field v-model="form.platform" label="Стек технологий / Среда исполнения" />
          <v-textarea v-model="form.content" label="Параметры интеграции, форматы сообщений или детальное техническое описание" />
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
const form = ref({ title: '', content: '', platform: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/architecture`)
  items.value = res.data
}

const openDialog = () => {
  form.value = { title: '', content: '', platform: '' }
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
    await httpClient.put(`projects/${props.projectGuid}/architecture/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/architecture`, form.value)
  }
  await load()
  dialog.value = false
}

const deleteItem = async (id) => {
  if (confirm('Удалить эту архитектурную запись?')) {
    await httpClient.delete(`projects/${props.projectGuid}/architecture/${id}`)
    await load()
  }
}

onMounted(load)
</script>
