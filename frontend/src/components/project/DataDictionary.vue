<template>
  <v-card class="ma-2" title="Словарь данных">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    <v-list>
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title><strong>{{ item.term }}</strong> ({{ item.type }})</v-list-item-title>
        <v-list-item-subtitle>{{ item.description }}</v-list-item-subtitle>
        <template #append>
          <v-btn icon="mdi-pencil" @click="editItem(item)" />
          <v-btn icon="mdi-delete" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать запись словаря' : 'Новая запись словаря' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.term" label="Термин" />
          <v-text-field v-model="form.type" label="Тип" />
          <v-textarea v-model="form.description" label="Описание" />
        </v-card-text>
        <v-card-actions>
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
const form = ref({ term: '', type: '', description: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/data-dictionary`)
  items.value = res.data
}
const openDialog = () => {
  form.value = { term: '', type: '', description: '' }
  editing.value = false
  dialog.value = true
}
const editItem = (item) => {
  form.value = { term: item.term, type: item.type, description: item.description }
  currentId.value = item.id
  editing.value = true
  dialog.value = true
}
const save = async () => {
  if (editing.value) {
    await httpClient.put(`projects/${props.projectGuid}/data-dictionary/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/data-dictionary`, form.value)
  }
  await load()
  dialog.value = false
}
const deleteItem = async (id) => {
  if (confirm('Удалить запись словаря?')) {
    await httpClient.delete(`projects/${props.projectGuid}/data-dictionary/${id}`)
    await load()
  }
}
onMounted(load)
</script>
