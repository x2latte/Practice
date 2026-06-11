<script setup lang="ts">
  import type { PropType } from 'vue'
  import type { ProjectType } from '@/stores/types/project_types.ts'

  const props = defineProps({
    item: Object as PropType<ProjectType>,
  })

  function stats_status (item: ProjectType | undefined) {
    const common = ' d-flex align-center'
    if (!item) {
      return common
    }
    if (item.common_stats < 33) {
      return 'bg-red' + common
    }
    if (item.common_stats < 66) {
      return 'bg-yellow' + common
    }
    return 'bg-green' + common
  }
</script>

<template>
  <v-card
    class="mx-auto"
    variant="outlined"
  >
    <div class="d-flex flex-no-wrap justify-space-between">
      <div>
        <v-card-title><RouterLink :to="{name:'project.dashboard', params: {projectGuid: props.item?.guid}}">{{ props.item?.name }}</RouterLink></v-card-title>
        <span class="pl-2 text-grey-darken-2">Заказчик: {{ props.item?.customer }}</span>
      </div>
      <div :class="stats_status(props.item)">
        <span class="stats text-center">{{ props.item?.common_stats }}%</span>
      </div>
    </div>
  </v-card>
</template>

<style scoped>
.stats {
  width: 50pt;
}
</style>
