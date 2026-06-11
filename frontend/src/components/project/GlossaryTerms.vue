<template>
  <v-card class="ma-2" title="Глоссарий терминов">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    <v-list>
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title><strong>{{ item.term }}</strong> — {{ item.definition }}</v-list-item-title>
        <template #append>
          <v-btn icon="mdi-pencil" @click="editItem(item)" />
          <v-btn icon="mdi-delete" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать термин' : 'Новый термин' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.term" label="Термин" />
          <v-textarea v-model="form.definition" label="Определение" />
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
const form = ref({ term: '', definition: '' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/glossary-terms`)
  items.value = res.data
}
const openDialog = () => {
  form.value = { term: '', definition: '' }
  editing.value = false
  dialog.value = true
}
const editItem = (item) => {
  form.value = { term: item.term, definition: item.definition }
  currentId.value = item.id
  editing.value = true
  dialog.value = true
}
const save = async () => {
  if (editing.value) {
    await httpClient.put(`projects/${props.projectGuid}/glossary-terms/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/glossary-terms`, form.value)
  }
  await load()
  dialog.value = false
}
const deleteItem = async (id) => {
  if (confirm('Удалить термин?')) {
    await httpClient.delete(`projects/${props.projectGuid}/glossary-terms/${id}`)
    await load()
  }
}
onMounted(load)
</script>
