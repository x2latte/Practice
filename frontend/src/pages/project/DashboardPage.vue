<script setup lang="ts">
import { httpClient } from '@/stores/api/base'

  import { onMounted } from 'vue'
  import { useRoute } from 'vue-router'
  import { useProjectDataStore } from '@/stores/project_data.ts'

  const route = useRoute()
  const projectGuid = route.params.projectGuid as string
  const projectStore = useProjectDataStore(projectGuid)()

  function get_common_color () {
    if (!projectStore.data || !projectStore.data.common_stats)
      return 'black'
    if (projectStore.data.common_stats < 33) {
      return 'red'
    }
    if (projectStore.data.common_stats < 66) {
      return 'yellow'
    }
    return 'green'
  }

  function progress (value: number | undefined) {
    if (!value)
      return `{height: 100%; padding-top: 1rem; background: linear-gradient(to right, #F44336 0%, #FDE7E5 0, #FDE7E5);}`

    if (value < 33) {
      return `{height: 100%; padding-top: 1rem; background: linear-gradient(to right, #F44336 ${value}%, #FDE7E5 0, #FDE7E5);}`
    }
    if (value < 66) {
      return `{height: 100%; padding-top: 1rem; background: linear-gradient(to right, #FFEB3B ${value}%, #FFFCE6 0, #FFFCE6);}`
    }
    return `{height: 100%; padding-top: 1rem; background: linear-gradient(to right, #4CAF50 ${value}%, #E8F5E9 0, #E8F5E9);}`
  }

const exportPDF = async () => {
  const response = await httpClient.get(`projects/${projectGuid}/export/pdf`, { responseType: "blob" });
  const url = window.URL.createObjectURL(new Blob([response.data]));
  const link = document.createElement("a");
  link.href = url;
  link.setAttribute("download", `tz_${projectGuid}.pdf`);
  document.body.appendChild(link);
  link.click();
  link.remove();
};
  onMounted(() => {
    if (!projectStore.isLoaded) {
      projectStore.loadData()
    }
    projectStore.loadStats()
  })
</script>

<template>
  <v-toolbar extended>
    <v-toolbar-title>{{ projectStore.data?.name }}</v-toolbar-title>
    <template #extension>
      <h1 class="ml-5 mt-1">Сводка по проекту</h1>
    <v-btn color="primary" @click="exportPDF" class="ml-5">Экспорт в PDF</v-btn>
    </template>
  </v-toolbar>

  <div><h2>Готовность ТЗ: {{ projectStore.data?.common_stats }}%</h2>
    <v-progress-linear :color="get_common_color()" height="20" :model-value="projectStore.data?.common_stats" />
  </div>
  <v-expansion-panels class="mt-3">
    <v-expansion-panel class="ma-1" :style="progress(projectStore.statsData?.annotation_stats)">
      <v-expansion-panel-title>
        <v-row>
          <v-col class="d-flex justify-start">Описание проекта</v-col>
          <v-col class="d-flex justify-end mr-3">Заполненность: {{ projectStore.statsData?.annotation_stats }}%</v-col>
        </v-row>
      </v-expansion-panel-title>
      <v-expansion-panel-text>
        <div>Число символов в аннотации: {{ projectStore.statsData?.abstract_length }} (мин.: 500)</div>
        <div>Число параграфов в аннотации: {{ projectStore.statsData?.abstract_paragraph_count }} (мин.: 2)</div>
      </v-expansion-panel-text>
    </v-expansion-panel>

    <v-expansion-panel class="ma-1" :style="progress(projectStore.statsData?.requirement_stats)">
      <v-expansion-panel-title>
        <v-row>
          <v-col class="d-flex justify-start">Требования</v-col>
          <v-col class="d-flex justify-end mr-3">Заполненность: {{ projectStore.statsData?.requirement_stats }}%</v-col>
        </v-row>
      </v-expansion-panel-title>
      <v-expansion-panel-text>
        <div>Число функциональных требований: {{ projectStore.statsData?.ft_count }} (мин. 10)</div>
        <div>Число функциональных ограничений: {{ projectStore.statsData?.fo_count }} (мин. 10)</div>
      </v-expansion-panel-text>
    </v-expansion-panel>
  </v-expansion-panels>
</template>

<style scoped>

</style>
