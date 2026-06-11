<template>
  <v-card class="ma-2" title="Потоки данных">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    <v-list>
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title><strong>{{ item.name }}</strong> ({{ item.source }} → {{ item.destination }})</v-list-item-title>
        <v-list-item-subtitle>{{ item.data }}</v-list-item-subtitle>
        <template #append>
          <v-btn icon="mdi-pencil" @click="editItem(item)" />
          <v-btn icon="mdi-delete" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать поток данных' : 'Новый поток данных' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.name" label="Название" />
          <v-text-field v-model="form.source" label="Источник" />
          <v-text-field v-model="form.destination" label="Назначение" />
          <v-textarea v-model="form.data" label="Данные" />
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
const form = ref({ name: '', source: '', destination: '', data: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/data-flows`)
  items.value = res.data
}
const openDialog = () => {
  form.value = { name: '', source: '', destination: '', data: '' }
  editing.value = false
  dialog.value = true
}
const editItem = (item) => {
  form.value = { name: item.name, source: item.source, destination: item.destination, data: item.data }
  currentId.value = item.id
  editing.value = true
  dialog.value = true
}
const save = async () => {
  if (editing.value) {
    await httpClient.put(`projects/${props.projectGuid}/data-flows/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/data-flows`, form.value)
  }
  await load()
  dialog.value = false
}
const deleteItem = async (id) => {
  if (confirm('Удалить поток данных?')) {
    await httpClient.delete(`projects/${props.projectGuid}/data-flows/${id}`)
    await load()
  }
}
onMounted(load)
</script>
