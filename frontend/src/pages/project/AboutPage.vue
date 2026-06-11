<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import EditLine from '@/components/project/EditLine.vue'
import EditTextArea from '@/components/project/EditTextArea.vue'
import { useProjectDataStore } from '@/stores/project_data.ts'
import BusinessGoals from '@/components/project/BusinessGoals.vue'
import GlossaryTerms from '@/components/project/GlossaryTerms.vue'
import UseCases from '@/components/project/UseCases.vue'
import DataFlows from '@/components/project/DataFlows.vue'
import DataDictionary from '@/components/project/DataDictionary.vue'
import NonFunctionalRequirements from '@/components/project/NonFunctionalRequirements.vue'
import Constraints from '@/components/project/Constraints.vue'
import SystemRequirements from '@/components/project/SystemRequirements.vue'
import Analogs from '@/components/project/Analogs.vue'
import UserClasses from '@/components/project/UserClasses.vue'
import UserStories from '@/components/project/UserStories.vue'
import Architecture from '@/components/project/Architecture.vue'
import DraftTZ from '@/components/project/DraftTZ.vue'
import FinalTZ from '@/components/project/FinalTZ.vue'
import ChangeRecords from '@/components/project/ChangeRecords.vue'

const route = useRoute()
const projectGuid = route.params.projectGuid as string
const store = useProjectDataStore(projectGuid)()

const tab = ref('details')
const isEditCustomer = ref(false)
const isEditAbstract = ref(false)

function edit(item: string) {
  switch (item) {
    case 'customer': isEditCustomer.value = !isEditCustomer.value; break
    case 'abstract': isEditAbstract.value = !isEditAbstract.value; break
  }
}

function saveValue(propName: string, propValue: string) {
  switch (propName) {
    case 'customer':
      store.updateVal('customer', propValue)
      isEditCustomer.value = false
      break
    case 'abstract':
      store.updateVal('abstract', propValue)
      isEditAbstract.value = false
      break
  }
}

onMounted(() => {
  if (!store.isLoaded) store.loadData()
})
</script>

<template>
  <v-toolbar extended>
    <v-toolbar-title>{{ store.data?.name }}</v-toolbar-title>
    <template #extension>
      <h1 class="ml-5 mt-1">Описание проекта</h1>
    </template>
  </v-toolbar>

  <v-tabs v-model="tab" show-arrows centered>
    <v-tab value="details">Основное</v-tab>
    <v-tab value="goals">Бизнес-цели</v-tab>
    <v-tab value="analogs">Аналоги</v-tab>
    <v-tab value="userclasses">Классы пользователей</v-tab>
    <v-tab value="userstories">User Stories</v-tab>
    <v-tab value="glossary">Глоссарий</v-tab>
    <v-tab value="usecases">Use Cases</v-tab>
    <v-tab value="architecture">Архитектура</v-tab>
    <v-tab value="dataflows">Потоки данных</v-tab>
    <v-tab value="datadict">Словарь данных</v-tab>
    <v-tab value="nfr">Нефункциональные</v-tab>
    <v-tab value="constraints">Ограничения</v-tab>
    <v-tab value="sysreq">Системные</v-tab>
    <v-tab value="drafttz">Черновик ТЗ</v-tab>
    <v-tab value="finaltz">Итоговое ТЗ</v-tab>
    <v-tab value="changes">Изменения</v-tab>
  </v-tabs>

  <v-window v-model="tab">
    <v-window-item value="details">
      <v-card class="ma-2" title="Заказчик">
        <template v-slot:append>
          <v-btn v-if="!isEditCustomer" icon="mdi-pencil" variant="text" @click="edit('customer')" />
        </template>
        <v-card-text>
          <EditLine :editing="isEditCustomer" :text="store.data ? (store.data.customer || '') : ''" @cancel:text="isEditCustomer=false" @update:text="(value) => saveValue('customer', value)" />
        </v-card-text>
      </v-card>
      <v-card class="ma-2" title="Аннотация">
        <template v-slot:append>
          <v-btn v-if="!isEditAbstract" icon="mdi-pencil" variant="text" @click="edit('abstract')" />
        </template>
        <v-card-text>
          <EditTextArea :editing="isEditAbstract" :text="store.data ? (store.data.abstract || '') : ''" @cancel:text="isEditAbstract=false" @update:text="(value) => saveValue('abstract', value)" />
        </v-card-text>
      </v-card>
    </v-window-item>

    <v-window-item value="goals">
      <BusinessGoals :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="analogs">
      <Analogs :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="userclasses">
      <UserClasses :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="userstories">
      <UserStories :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="glossary">
      <GlossaryTerms :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="usecases">
      <UseCases :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="architecture">
      <Architecture :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="dataflows">
      <DataFlows :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="datadict">
      <DataDictionary :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="nfr">
      <NonFunctionalRequirements :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="constraints">
      <Constraints :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="sysreq">
      <SystemRequirements :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="drafttz">
      <DraftTZ :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="finaltz">
      <FinalTZ :project-guid="projectGuid" />
    </v-window-item>
    <v-window-item value="changes">
      <ChangeRecords :project-guid="projectGuid" />
    </v-window-item>
  </v-window>
</template>
