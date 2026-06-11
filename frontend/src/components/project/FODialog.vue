<script setup lang="ts">

  import { reactive, ref } from 'vue'
  import { validators } from '@/stores/api/utils.ts'
  import { useProjectsStore } from '@/stores/projects.ts'

  const props = defineProps({
    projectGuid: {
      type: String,
      required: true,
    },
  })

  const emit = defineEmits(['success'])

  const openDialog = ref<boolean>(false)

  const formData = reactive({
    title: '',
    is_functional: false,
    description: '',
    priority: 0,
  })

  const store = useProjectsStore()

  function submit () {
    if (formStatus.value) {
      isInProgress.value = true
      try {
        if (reqId.value) {
          store.updateRequirement(reqId.value, formData).then(() => {
            openDialog.value = false
            emit('success')
          })
        } else {
          store.createRequirement(props.projectGuid, formData).then(() => {
            openDialog.value = false
            emit('success')
          })
        }
      } catch {}
      isInProgress.value = false
    }
  }

  const formStatus = ref(false)
  const isInProgress = ref(false)

  function open () {
    formData.title = ''
    formData.description = ''
    formData.priority = 0
    openDialog.value = true
  }

  const reqId = ref('')

  function edit (item: any) {
    formData.title = item.title
    formData.description = item.description
    formData.priority = item.priority
    reqId.value = item.guid
    openDialog.value = true
  }

  defineExpose({ open, edit })
</script>

<template>
  <v-dialog v-model="openDialog" max-width="800" persistent>
    <VForm v-model="formStatus" @submit.prevent="submit">
      <v-card>
        <div v-if="reqId">
          <v-card-title>Редактирование ограничения (ФО)</v-card-title>
        </div>
        <div v-else>
          <v-card-title>Добавление органичения (ФО)</v-card-title>
        </div>
        <v-card-text>
          <v-row density="comfortable">
            <v-col
              cols="12"
            >
              <v-text-field
                v-model="formData.title"
                label="Краткое название*"
                required
                :rules="[validators.required]"
              />
            </v-col>
            <v-col
              cols="12"
            >
              <v-textarea v-model="formData.description" label="Описание" />
            </v-col>
          </v-row>
          <v-row>
            <VCol v-if="store.error" cols="12">
              <VAlert
                type="error"
              >
                {{ store.error }}
              </VAlert>
            </VCol>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-btn
            text="Отмена"
            variant="plain"
            @click="openDialog=false"
          />
          <v-btn
            :disabled="!formStatus&&isInProgress"
            :loading="isInProgress"
            text="Сохранить"
            type="submit"
            variant="tonal"
          />
        </v-card-actions>
      </v-card>
    </VForm>
  </v-dialog>
</template>

<style scoped>

</style>
