<script setup lang="ts">

  import { reactive, ref } from 'vue'
  import { useRouter } from 'vue-router'
  import { validators } from '@/stores/api/utils'
  import { useProjectsStore } from '@/stores/projects'

  const store = useProjectsStore()
  const { push } = useRouter()

  const formData = reactive({
    name: '',
    customer: '',
    abstract: '',
  })

  const errorMsg = ref('')
  const isInProgress = ref(false)
  const formStatus = ref(false)

  function submit () {
    if (formStatus.value) {
      isInProgress.value = true
      try {
        store.createProject(formData).then(() => {
          push({ name: 'projects' })
        })
      } catch (error: any) {
        errorMsg.value = error.message
      }
      isInProgress.value = false
    }
  }

</script>

<template>
  <h1>Создание проекта</h1>
  <v-form v-model="formStatus" @submit.prevent="submit">
    <v-row>
      <v-col cols="12">
        <VTextField
          v-model="formData.name"
          label="Имя проекта"
          :rules="[validators.required]"
        />
      </v-col>
      <v-col cols="12">
        <VTextField
          v-model="formData.customer"
          label="Заказчик"
          :rules="[validators.required]"
        />
      </v-col>
      <v-col cols="12">
        <VTextarea
          v-model="formData.abstract"
          auto-grow
          counter
          label="Аннотация проекта"
          max-height="400"
          maxlength="2000"
          :rules="[validators.required]"
        />
      </v-col>
      <VCol v-if="errorMsg" cols="12">
        <VAlert
          type="error"
        >
          {{ errorMsg }}
        </VAlert>
      </VCol>

      <VBtn
        color="primary"
        :disabled="!formStatus&&isInProgress"
        :loading="isInProgress"
        type="submit"
      >Создать проект</VBtn>

    </v-row>
  </v-form>
</template>

<style scoped>

</style>
