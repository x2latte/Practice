<script setup lang="ts">
  import type { RequirementType } from '@/stores/types/project_types.ts'
  import { computed, onMounted, onUpdated, type PropType, ref } from 'vue'
  import { useRequirementDataStore } from '@/stores/requirement_data.ts'

  const props = defineProps({
    item: Object as PropType<RequirementType>,
  })

  const store = useRequirementDataStore(props.item!.guid)()

  defineEmits(['edit', 'delete'])

  const priority = computed(() => {
    switch (store.data?.priority) {
      case 0: {
        return 'Высокий'
      }
      case 1: {
        return 'Средний'
      }
      case 2: {
        return 'Низкий'
      }
      default: {
        return 'Неизвестный'
      }
    }
  })

  const show = ref(false)

  onMounted(() => {
    if (!store.isLoaded || props.item!.updated_at != store.data!.updated_at) {
      store.loadData()
    }
  })

  onUpdated(() => {
    if (!store.isLoaded || props.item!.updated_at != store.data!.updated_at) {
      store.loadData()
    }
  })
</script>

<template>
  <v-card
    class="mx-auto"
    variant="outlined"
  >
    <template #title><div @click="show = !show">{{ store.data!.alias }}: {{ store.data!.title }}</div></template>
    <template #subtitle><div @click="show = !show"><span>Тип: {{ store.data!.is_functional ? 'ФТ' : 'ФО' }}</span>,
      <span>Приоритет: {{ priority }}</span></div></template>
    <v-card-actions v-if="show">
      <v-btn @click="$emit('edit', store.data)">Редактировать</v-btn>
      <v-btn @click="$emit('delete', props.item!.guid)">Удалить</v-btn>
    </v-card-actions>
    <v-expand-transition>
      <div v-show="show">
        <v-card-text>
          {{ store.data?.description }}
        </v-card-text>
      </div>
    </v-expand-transition>
  </v-card>
</template>

<style scoped>

</style>
