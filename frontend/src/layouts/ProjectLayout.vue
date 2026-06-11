<script setup lang="ts">

  import { useRoute } from 'vue-router'
  import MFooter from '@/components/MFooter.vue'
  import MHeader from '@/components/MHeader.vue'

  const route = useRoute()
  const projectGuid = route.params.projectGuid
</script>

<template>
  <VLayout class="rounded rounded-md border" min-height="100%">
    <MHeader />
    <VMain>
      <v-navigation-drawer>
        <v-list nav>
          <v-list-item :to="{name: 'project.dashboard', params:{projectGuid: projectGuid}}">Сводка</v-list-item>
          <v-list-item :to="{name: 'project.about', params:{projectGuid: projectGuid}}">Описание</v-list-item>
          <v-list-item :to="{name: 'project.requirements', params:{projectGuid: projectGuid}}">Требования</v-list-item>
        </v-list>
      </v-navigation-drawer>
      <v-container>
        <RouterView />
      </v-container>
    </VMain>
    <MFooter />
  </VLayout>
</template>

<style scoped>

</style>
