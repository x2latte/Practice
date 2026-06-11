<script setup lang="ts">

  import { useRouter } from 'vue-router'
  import { useUserStore } from '@/stores/user'

  const store = useUserStore()
  const { push } = useRouter()

  function processMenuItem (name: string) {
    switch (name) {
      case 'exit': {
        store.logout()
        push({ name: 'login' })
        break
      }
      case 'profile': {
        push({ name: 'profile' })
        break
      }
      case 'projects': {
        push({ name: 'projects' })
        break
      }
      case 'admin': {
        push({ name: 'admin' })
        break
      }
      default: {
        alert('Not implemented!! Please try again: ' + name)
      }
    }
  }
</script>

<template>
  <VAppBar>
    <VAppBarTitle tag="div">
      <RouterLink to="/">RAS</RouterLink>
      <VBtn class="ml-3" rounded variant="plain" @click="processMenuItem('projects')">Проекты</VBtn>
      <VBtn v-if="store.profile.is_admin" rounded variant="plain" @click="processMenuItem('admin')">Администрирование</VBtn>
    </VAppBarTitle>
    <v-menu min-width="200px">
      <template #activator="{ props }">
        <v-btn
          icon
          v-bind="props"
        >
          <v-avatar
            color="brown"
            size="large"
          >
            <span class="text-headline-small">{{ store.initials }}</span>
          </v-avatar>
        </v-btn>
      </template>
      <v-card>
        <v-card-text>
          <div class="mx-auto text-center">
            <v-avatar
              color="brown"
            >
              <span class="text-headline-small">{{ store.initials }}</span>
            </v-avatar>
            <h3 class="my-0">{{ store.profile.name }}</h3>
            <p class="text-body-small mt-1">
              {{ store.profile.login }}
            </p>
            <v-divider class="my-3" />
            <v-btn
              rounded
              variant="text"
              @click="processMenuItem('profile')"
            >
              Профиль
            </v-btn>
            <v-divider class="my-3" />
            <v-btn
              rounded
              variant="text"
              @click="processMenuItem('exit')"
            >
              Выход
            </v-btn>
          </div>
        </v-card-text>
      </v-card>
    </v-menu>
  </VAppBar>
</template>

<style scoped>

</style>
