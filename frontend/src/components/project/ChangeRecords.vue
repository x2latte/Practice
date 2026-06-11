<template>
  <v-card class="ma-2" title="Внесение изменений в ТЗ">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    
    <v-list v-if="items.length > 0">
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title class="font-weight-bold">
          Версия {{ item.title }} 
          <span class="text-caption ml-2 text-grey">({{ item.date || '-' }})</span>
        </v-list-item-title>
        <v-list-item-subtitle v-if="item.author"><strong>Кто внес изменения:</strong> {{ item.author }}</v-list-item-subtitle>
        <div class="text-body-2 mt-1">{{ item.content }}</div>
        
        <template #append>
          <v-btn icon="mdi-pencil" variant="text" @click="editItem(item)" />
          <v-btn icon="mdi-delete" variant="text" color="error" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-card-text v-else class="text-center text-grey">
      Изменения в ТЗ пока не зафиксированы. Нажмите "+" чтобы добавить запись об изменении.
    </v-card-text>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать запись об изменении' : 'Добавить запись об изменении' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.title" label="Версия ТЗ (например: 1.1, 2.0-draft)" />
          <v-text-field v-model="form.author" label="Автор изменений (ФИО)" />
          <v-text-field v-model="form.date" label="Дата внесения изменений" type="date" />
          <v-textarea v-model="form.content" label="Краткое описание перечня внесенного изменения" />
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
const form = ref({ title: '', content: '', author: '', date: new Date().toISOString().substring(0, 10) })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/changes`)
  items.value = res.data
}

const openDialog = () => {
  form.value = { title: '', content: '', author: '', date: new Date().toISOString().substring(0, 10) }
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
    await httpClient.put(`projects/${props.projectGuid}/changes/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/changes`, form.value)
  }
  await load()
  dialog.value = false
}

const deleteItem = async (id) => {
  if (confirm('Удалить эту запись об изменении ТЗ?')) {
    await httpClient.delete(`projects/${props.projectGuid}/changes/${id}`)
    await load()
  }
}

onMounted(load)
</script>
