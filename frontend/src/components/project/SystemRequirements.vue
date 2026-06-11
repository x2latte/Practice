<template>
  <v-card class="ma-2" title="Системные требования">
    <template #append>
      <v-btn icon="mdi-pencil" @click="editRequirements" />
    </template>
    <v-card-text>
      <div><strong>Аппаратные требования:</strong> {{ data.hardware || 'не указаны' }}</div>
      <div><strong>Программные требования:</strong> {{ data.software || 'не указаны' }}</div>
      <div><strong>Сетевые требования:</strong> {{ data.network || 'не указаны' }}</div>
    </v-card-text>
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>Редактировать системные требования</v-card-title>
        <v-card-text>
          <v-textarea v-model="form.hardware" label="Аппаратные требования" />
          <v-textarea v-model="form.software" label="Программные требования" />
          <v-textarea v-model="form.network" label="Сетевые требования" />
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
const data = ref({ hardware: '', software: '', network: '' })
const dialog = ref(false)
const form = ref({ hardware: '', software: '', network: '' })

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/system-requirements`)
  data.value = res.data || { hardware: '', software: '', network: '' }
}
const editRequirements = () => {
  form.value = { ...data.value }
  dialog.value = true
}
const save = async () => {
  if (data.value.id) {
    await httpClient.put(`projects/${props.projectGuid}/system-requirements`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/system-requirements`, form.value)
  }
  await load()
  dialog.value = false
}
onMounted(load)
</script>
