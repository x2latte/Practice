<script setup lang="ts">

  const props = defineProps({
    title: String,
  })
</script>

<template>
  <div>
    "{{ props.title }}" находятся в разработке
  </div>
</template>

<style scoped>

</style>
