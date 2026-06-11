<template>
  <v-card class="ma-2" title="Классы пользователей">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    
    <v-list v-if="items.length > 0">
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title class="font-weight-bold">
          {{ item.title }} 
          <span class="text-caption ml-2 text-primary" v-if="item.complexity">({{ item.complexity }})</span>
        </v-list-item-title>
        <div class="text-body-2 mt-1">{{ item.content }}</div>
        
        <template #append>
          <v-btn icon="mdi-pencil" variant="text" @click="editItem(item)" />
          <v-btn icon="mdi-delete" variant="text" color="error" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-card-text v-else class="text-center text-grey">
      Классы пользователей не описаны. Нажмите "+" чтобы добавить.
    </v-card-text>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать класс' : 'Добавить класс' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.title" label="Класс (например, Администратор, Покупатель)" />
          <v-select v-model="form.complexity" :items="['Сложный', 'Средний', 'Простой']" label="Критичность / Сложность" />
          <v-textarea v-model="form.content" label="Описание роли, прав доступа, частоты использования" />
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
const form = ref({ title: '', content: '', complexity: 'Средний' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/user-classes`)
  items.value = res.data
}

const openDialog = () => {
  form.value = { title: '', content: '', complexity: 'Средний' }
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
    await httpClient.put(`projects/${props.projectGuid}/user-classes/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/user-classes`, form.value)
  }
  await load()
  dialog.value = false
}

const deleteItem = async (id) => {
  if (confirm('Удалить этот класс пользователей?')) {
    await httpClient.delete(`projects/${props.projectGuid}/user-classes/${id}`)
    await load()
  }
}

onMounted(load)
</script>
