<script setup lang="ts">
import { ref } from 'vue'
import MermaidDiagram from '@/components/MermaidDiagram.vue'
const diagramCode = ref(`graph TD
    A[Функциональные требования] --> B[ФТ1]
    A --> C[ФТ2]
    D[Ограничения] --> E[ФО1]`)
</script>

<template>
  <v-textarea v-model="diagramCode" label="Диаграмма Mermaid" rows="10"></v-textarea>
  <MermaidDiagram :diagram="diagramCode" />
</template>
