<template>
  <v-card class="ma-2" title="Нефункциональные требования">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    <v-list>
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title><strong>{{ item.category }}</strong> — {{ item.description }}</v-list-item-title>
        <v-list-item-subtitle v-if="item.metric">Метрика: {{ item.metric }}</v-list-item-subtitle>
        <template #append>
          <v-btn icon="mdi-pencil" @click="editItem(item)" />
          <v-btn icon="mdi-delete" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать НФТ' : 'Новое НФТ' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.category" label="Категория" />
          <v-textarea v-model="form.description" label="Описание" />
          <v-text-field v-model="form.metric" label="Метрика" />
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
const form = ref({ category: '', description: '', metric: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/non-functional-requirements`)
  items.value = res.data
}
const openDialog = () => {
  form.value = { category: '', description: '', metric: '' }
  editing.value = false
  dialog.value = true
}
const editItem = (item) => {
  form.value = { category: item.category, description: item.description, metric: item.metric || '' }
  currentId.value = item.id
  editing.value = true
  dialog.value = true
}
const save = async () => {
  if (editing.value) {
    await httpClient.put(`projects/${props.projectGuid}/non-functional-requirements/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/non-functional-requirements`, form.value)
  }
  await load()
  dialog.value = false
}
const deleteItem = async (id) => {
  if (confirm('Удалить НФТ?')) {
    await httpClient.delete(`projects/${props.projectGuid}/non-functional-requirements/${id}`)
    await load()
  }
}
onMounted(load)
</script>
