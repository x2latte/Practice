<template>
  <v-card class="ma-2" title="Use Cases">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    <v-list>
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title><strong>{{ item.name }}</strong> (Актёр: {{ item.actor }})</v-list-item-title>
        <v-list-item-subtitle>{{ item.flow }}</v-list-item-subtitle>
        <template #append>
          <v-btn icon="mdi-pencil" @click="editItem(item)" />
          <v-btn icon="mdi-delete" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать Use Case' : 'Новый Use Case' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.name" label="Название" />
          <v-text-field v-model="form.actor" label="Актёр" />
          <v-textarea v-model="form.preconditions" label="Предусловия" />
          <v-textarea v-model="form.flow" label="Основной поток" />
          <v-textarea v-model="form.exceptions" label="Исключения" />
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
const form = ref({ name: '', actor: '', preconditions: '', flow: '', exceptions: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/use-cases`)
  items.value = res.data
}
const openDialog = () => {
  form.value = { name: '', actor: '', preconditions: '', flow: '', exceptions: '' }
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
    await httpClient.put(`projects/${props.projectGuid}/use-cases/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/use-cases`, form.value)
  }
  await load()
  dialog.value = false
}
const deleteItem = async (id) => {
  if (confirm('Удалить Use Case?')) {
    await httpClient.delete(`projects/${props.projectGuid}/use-cases/${id}`)
    await load()
  }
}
onMounted(load)
</script>
