<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import ProjectPanel from '@/components/project/ProjectPanel.vue'
import { useProjectsStore } from '@/stores/projects.ts'
import type { ProjectType } from '@/stores/types/project_types'
import { httpClient } from '@/stores/api/base'

const store = useProjectsStore()
const search = ref('')
const sortBy = ref<keyof ProjectType>('name')
const sortDesc = ref(false)

const itemsList = ref<ProjectType[]>([])

const filteredAndSorted = computed(() => {
  let result = [...itemsList.value]
  if (search.value) {
    const s = search.value.toLowerCase()
    result = result.filter(p => p.name.toLowerCase().includes(s) || p.customer.toLowerCase().includes(s))
  }
  result.sort((a, b) => {
    let valA: string | number = a[sortBy.value] as string | number
    let valB: string | number = b[sortBy.value] as string | number
    if (sortBy.value === 'common_stats') {
      valA = parseFloat(valA as string)
      valB = parseFloat(valB as string)
    }
    if (valA < valB) return sortDesc.value ? 1 : -1
    if (valA > valB) return sortDesc.value ? -1 : 1
    return 0
  })
  return result
})

const deleteProject = async (guid: string) => {
  if (confirm('Удалить проект?')) {
    await httpClient.delete(`projects/${guid}`)
    itemsList.value = itemsList.value.filter(p => p.guid !== guid)
  }
}

onMounted(async () => {
  itemsList.value = await store.getProjects()
})
</script>

<template>
  <v-toolbar title="Проекты">
    <v-btn color="primary" rounded to="projects/create">Создать</v-btn>
  </v-toolbar>

  <v-text-field v-model="search" label="Поиск по названию/заказчику" clearable class="mx-4"></v-text-field>

  <v-select v-model="sortBy" :items="[{title:'Название',value:'name'},{title:'Заказчик',value:'customer'},{title:'Готовность',value:'common_stats'}]" label="Сортировать по" class="mx-4"></v-select>
  <v-switch v-model="sortDesc" label="По убыванию" class="mx-4"></v-switch>

  <v-alert v-if="store.error" type="error" class="mx-4">{{ store.error }}</v-alert>

  <v-list>
    <v-list-item v-for="item in filteredAndSorted" :key="item.guid">
      <ProjectPanel :item="item" />
      <v-btn color="error" size="small" class="ml-2" @click="deleteProject(item.guid)">Удалить</v-btn>
    </v-list-item>
  </v-list>
</template>
