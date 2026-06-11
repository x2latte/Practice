<template>
  <div ref="container" class="mermaid"></div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import mermaid from 'mermaid'

const props = defineProps<{ diagram: string }>()
const container = ref<HTMLElement>()

onMounted(() => {
  mermaid.initialize({ startOnLoad: false })
  renderDiagram()
})

watch(() => props.diagram, renderDiagram)

async function renderDiagram() {
  if (!container.value) return
  const { svg } = await mermaid.render('mermaid-svg', props.diagram)
  container.value.innerHTML = svg
}
</script>
