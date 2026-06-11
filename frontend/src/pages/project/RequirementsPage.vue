<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import FODialog from '@/components/project/FODialog.vue'
import FTDialog from '@/components/project/FTDialog.vue'
import RequirementPanel from '@/components/project/RequirementPanel.vue'
import { useProjectDataStore } from '@/stores/project_data.ts'
import { useProjectsStore } from '@/stores/projects.ts'
import type { RequirementType } from '@/stores/types/project_types'

const route = useRoute()
const projectGuid = route.params.projectGuid as string

const store = useProjectsStore()
const projectStore = useProjectDataStore(projectGuid)()

const ftDialog = ref<InstanceType<typeof FTDialog> | null>(null)
const foDialog = ref<InstanceType<typeof FODialog> | null>(null)
const itemsList = ref<RequirementType[]>([])

const filterType = ref<'all' | 'functional' | 'nonfunctional'>('all')
const filterPriority = ref<string | number>('all')
const searchTitle = ref('')

const filteredItems = computed(() => {
  let result = [...itemsList.value]
  if (filterType.value !== 'all') {
    const isFunc = filterType.value === 'functional'
    result = result.filter(r => r.is_functional === isFunc)
  }
  if (filterPriority.value !== 'all') {
    result = result.filter(r => r.priority === Number(filterPriority.value))
  }
  if (searchTitle.value) {
    const s = searchTitle.value.toLowerCase()
    result = result.filter(r => r.title.toLowerCase().includes(s) || r.alias.toLowerCase().includes(s))
  }
  return result
})

function openft() { ftDialog.value?.open() }
function openfo() { foDialog.value?.open() }
function updateList() { store.getRequirements(projectGuid).then(items => itemsList.value = items) }
async function deleteReq(item: RequirementType) { 
  await store.deleteRequirement(item.guid)
  updateList()
}
function editReq(item: RequirementType) { 
  item.is_functional ? ftDialog.value?.edit(item) : foDialog.value?.edit(item) 
}

onMounted(() => {
  updateList()
  if (!projectStore.isLoaded) projectStore.loadData()
})
</script>

<template>
  <FTDialog ref="ftDialog" :project-guid="projectGuid" @success="updateList" />
  <FODialog ref="foDialog" :project-guid="projectGuid" @success="updateList" />

  <v-toolbar extended>
    <v-toolbar-title>{{ projectStore.data?.name }}</v-toolbar-title>
    <v-btn color="primary" rounded @click="openft">Добавить функцию (ФТ)</v-btn>
    <v-btn color="primary" rounded @click="openfo">Добавить ограничение (ФО)</v-btn>
    <template #extension>
      <h1 class="ml-5 mt-1">Требования к ПО</h1>
    </template>
  </v-toolbar>

  <v-row class="mx-2">
    <v-col cols="12" md="4"><v-text-field v-model="searchTitle" label="Поиск по названию/алиасу" clearable></v-text-field></v-col>
    <v-col cols="12" md="4"><v-select v-model="filterType" :items="[{title:'Все',value:'all'},{title:'ФТ',value:'functional'},{title:'ФО',value:'nonfunctional'}]" label="Тип требования"></v-select></v-col>
    <v-col cols="12" md="4"><v-select v-model="filterPriority" :items="[{title:'Все',value:'all'},{title:'Высокий',value:0},{title:'Средний',value:1},{title:'Низкий',value:2}]" label="Приоритет"></v-select></v-col>
  </v-row>

  <v-alert v-if="store.error" type="error" class="mx-2">{{ store.error }}</v-alert>

  <v-list>
    <v-list-item v-for="item in filteredItems" :key="item.guid">
      <RequirementPanel :item="item" @delete="deleteReq" @edit="editReq" />
    </v-list-item>
  </v-list>
</template>
