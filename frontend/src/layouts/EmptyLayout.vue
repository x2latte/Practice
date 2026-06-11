<script setup lang="ts">

  import MFooter from '@/components/MFooter.vue'
</script>

<template>
  <VLayout class="rounded rounded-md border" min-height="100%">
    <VContainer>
      <RouterView />
    </VContainer>
    <MFooter />
  </VLayout>
</template>

<style scoped>

</style>
