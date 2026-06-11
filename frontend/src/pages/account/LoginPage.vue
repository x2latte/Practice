<script setup lang="ts">
  import { reactive, ref } from 'vue'
  import { useRouter } from 'vue-router'
  import { validators } from '@/stores/api/utils'
  import { useUserStore } from '@/stores/user'

  const store = useUserStore()
  const { push } = useRouter()

  const formData = reactive({
    username: '',
    password: '',
  })

  const isInProgress = ref(false)

  function submit () {
    if (formStatus.value) {
      isInProgress.value = true
      try {
        store.login(formData).then(() => {
          push({ name: 'projects' })
        })
      } catch {}
      isInProgress.value = false
    }
  }

  const formStatus = ref(false)
  const isPasswordVisible = ref(false)

</script>

<template>
  <div class="align-center justify-center d-flex pa-14">
    <VCard max-width="448">
      <VCardItem>
        <h2 class="text-uppercase">Авторизация</h2>
      </VCardItem>
      <VCardText>
        <VForm v-model="formStatus" @submit.prevent="submit">
          <VRow>
            <!-- Имя пользователя -->
            <VCol cols="12">
              <VTextField
                v-model="formData.username"
                hint="Введите имя пользователя или Email"
                label="Логин"
                :rules="[validators.required]"
              />
            </VCol>

            <!-- пароль -->
            <VCol cols="12">
              <VTextField
                v-model="formData.password"
                :append-inner-icon="isPasswordVisible ? 'mdi-eye-outline' : 'mdi-eye-off-outline'"
                autocomplete="password"
                label="Пароль"
                :rules="[validators.required]"
                :type="isPasswordVisible ? 'text' : 'password'"
                @click:append-inner="isPasswordVisible = !isPasswordVisible"
              />
            </VCol>

            <VCol v-if="store.error" cols="12">
              <VAlert
                type="error"
              >
                {{ store.error }}
              </VAlert>
            </VCol>

            <VBtn
              block
              :disabled="!formStatus&&isInProgress"
              :loading="isInProgress"
              type="submit"
            >Вход</VBtn>

            <VCol class="text-center" cols="12">
              <span>Нет учетной записи?</span>
              <RouterLink
                class="ms-2"
                to="signup"
              >
                Зарегистрироваться
              </RouterLink>
            </VCol>
          </VRow>
        </VForm>
      </VCardText>
    </VCard>
  </div>
</template>

<style scoped>

</style>
