<script setup lang="ts">

  import { computed, ref } from 'vue'

  const props = defineProps({
    text: {
      type: String,
      required: true,
    },
    editing: {
      type: Boolean,
      default: false,
    },
  })
  const emit = defineEmits(['update:text', 'cancel:text'])

  const newVal = ref()

  const value = computed({
    get () {
      if (newVal.value)
        return newVal.value
      return props.text
    },
    set (value) {
      newVal.value = value
    },
  })
</script>

<template>
  <div v-if="props.editing">
    <v-text-field
      v-model="value"
      autofocus
      hide-details
      label="Редактировать"
      variant="underlined"
    ><template #append>
      <v-btn @click="emit('update:text', newVal)">Сохранить</v-btn>
      <v-btn @click="newVal = ''; emit('cancel:text')">Отмена</v-btn>
    </template></v-text-field>
  </div>
  <div v-else>
    {{ props.text }}
  </div>
</template>

<style scoped>

</style>
