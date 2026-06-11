<script setup lang="ts">

  import { reactive, ref } from 'vue'
  import { useRouter } from 'vue-router'
  import { validators } from '@/stores/api/utils'
  import { useUserStore } from '@/stores/user'

  const store = useUserStore()
  const { push } = useRouter()

  const formData = reactive({
    name: '',
    email: '',
    username: '',
    password: '',
    password2: '',
  })

  const isInProgress = ref(false)

  function submit () {
    if (formStatus.value) {
      isInProgress.value = true
      try {
        store.register(formData.name, formData.email, formData.username, formData.password).then(() => {
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
        <h2 class="text-uppercase">Регистрация пользователя</h2>
      </VCardItem>
      <VCardText>
        <VForm v-model="formStatus" @submit.prevent="submit">
          <VRow>
            <!-- Имя пользователя -->
            <VCol cols="12">
              <VTextField
                v-model="formData.name"
                hint="Введите свое имя, оно будет использоваться для отображения в системе"
                label="Имя пользователя"
                :rules="[validators.required]"
              />
            </VCol>

            <!-- логин -->
            <VCol cols="12">
              <VTextField
                v-model="formData.email"
                hint="Введите свою электронную почту. Она используется для идентификации и отправки уведомлений"
                label="Email"
                :rules="[validators.required, validators.email]"
              />
            </VCol>

            <!-- логин -->
            <VCol cols="12">
              <VTextField
                v-model="formData.username"
                autocomplete="username"
                hint="Введите имя учетной записи, оно будет использоваться для идентификации вас в системе"
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
                hint="Пароль должен быть длиннее 8 знаков, содержать заглавные и строчные буквы, цифры и спецзнаки"
                label="Пароль"
                :rules="[validators.required]"
                :type="isPasswordVisible ? 'text' : 'password'"
                @click:append-inner="isPasswordVisible = !isPasswordVisible"
              />
            </VCol>

            <!-- повтор пароля -->
            <VCol cols="12">
              <VTextField
                v-model="formData.password2"
                :append-inner-icon="isPasswordVisible ? 'mdi-eye-outline' : 'mdi-eye-off-outline'"
                autocomplete="password"
                label="Повтор пароля"
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
            >Регистрация</VBtn>

            <VCol class="text-center" cols="12">
              <span>Есть учетная запись?</span>
              <RouterLink
                class="ms-2"
                to="signup"
              >
                Авторизоваться
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
