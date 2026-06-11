<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import fileService from '@/stores/api/fileService'
import type { FileInfoType } from '@/stores/types/project_types'

const route = useRoute()
const projectGuid = route.params.projectGuid as string
const files = ref<FileInfoType[]>([])
const uploading = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)

async function loadFiles() {
  files.value = await fileService.getFiles(projectGuid)
}

async function onFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploading.value = true
  await fileService.uploadFile(projectGuid, file)
  await loadFiles()
  uploading.value = false
}

async function deleteFile(fileGuid: string) {
  if (confirm('Удалить файл?')) {
    await fileService.deleteFile(projectGuid, fileGuid)
    await loadFiles()
  }
}

onMounted(loadFiles)
</script>

<template>
  <v-toolbar extended>
    <v-toolbar-title>Файлы проекта</v-toolbar-title>
    <template #extension>
      <v-btn :loading="uploading" @click="fileInput?.click()">Загрузить файл</v-btn>
      <input ref="fileInput" type="file" style="display:none" @change="onFileSelected" />
    </template>
  </v-toolbar>
  <v-list>
    <v-list-item v-for="f in files" :key="f.guid">
      <v-list-item-title>{{ f.filename }} ({{ f.file_size }} bytes)</v-list-item-title>
      <template #append>
        <v-btn icon="mdi-delete" @click="deleteFile(f.guid)"></v-btn>
      </template>
    </v-list-item>
  </v-list>
</template>
