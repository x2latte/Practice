<template>
  <v-card class="ma-2" title="Черновая версия ТЗ и Экспертные замечания">
    <template #append>
      <v-btn icon="mdi-plus" @click="openDialog()" />
    </template>
    
    <v-list v-if="items.length > 0">
      <v-list-item v-for="item in items" :key="item.id">
        <v-list-item-title class="font-weight-bold">
          {{ item.title }} 
          <span class="text-caption ml-2" :class="item.status === 'Утверждено' ? 'text-success' : 'text-warning'">
            ({{ item.status || 'На проверке' }})
          </span>
        </v-list-item-title>
        <div class="text-body-2 mt-1">{{ item.content }}</div>
        
        <template #append>
          <v-btn icon="mdi-pencil" variant="text" @click="editItem(item)" />
          <v-btn icon="mdi-delete" variant="text" color="error" @click="deleteItem(item.id)" />
        </template>
      </v-list-item>
    </v-list>
    <v-card-text v-else class="text-center text-grey">
      Описания черновых версий или комментариев нет. Нажмите "+" чтобы добавить.
    </v-card-text>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editing ? 'Редактировать запись о черновом ТЗ' : 'Добавить запись о черновом ТЗ' }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.title" label="Раздел чернового ТЗ / Номер версии" />
          <v-select v-model="form.status" :items="['На проверке', 'Требует доработки', 'Утверждено']" label="Статус рецензии" />
          <v-textarea v-model="form.content" label="Замечания эксперта / Результаты интервью / Текст раздела" />
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
const form = ref({ title: '', content: '', status: 'На проверке' })
const currentId = ref(null)

const load = async () => {
  const res = await httpClient.get(`projects/${props.projectGuid}/draft-tz`)
  items.value = res.data
}

const openDialog = () => {
  form.value = { title: '', content: '', status: 'На проверке' }
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
    await httpClient.put(`projects/${props.projectGuid}/draft-tz/${currentId.value}`, form.value)
  } else {
    await httpClient.post(`projects/${props.projectGuid}/draft-tz`, form.value)
  }
  await load()
  dialog.value = false
}

const deleteItem = async (id) => {
  if (confirm('Удалить эту черновую запись?')) {
    await httpClient.delete(`projects/${props.projectGuid}/draft-tz/${id}`)
    await load()
  }
}

onMounted(load)
</script>
