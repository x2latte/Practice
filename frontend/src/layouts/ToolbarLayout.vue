<script setup lang="ts">

  import MFooter from '@/components/MFooter.vue'
  import MHeader from '@/components/MHeader.vue'
</script>

<template>
  <VLayout class="rounded rounded-md border" min-height="100%">
    <MHeader />
    <VMain>
      <v-container>
        <RouterView />
      </v-container>
    </VMain>
    <MFooter />
  </VLayout>
</template>

<style scoped>

</style>
