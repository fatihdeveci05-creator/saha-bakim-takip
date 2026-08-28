<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const auth = useAuth()
const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function onSubmit() {
  error.value = ''
  loading.value = true
  try {
    await auth.login(email.value, password.value)
    if (auth.user.value?.taraf !== 'isveren') {
      auth.logout()
      error.value = 'Web paneli sadece işveren tarafı içindir'
      return
    }
    await navigateTo('/')
  } catch (err) {
    error.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Giriş başarısız'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-wrap">
    <form class="card login-card" @submit.prevent="onSubmit">
      <h1>ABB Kontrol</h1>
      <p class="muted">İşveren yönetim paneli</p>

      <div v-if="error" class="error-box">{{ error }}</div>

      <div class="field">
        <label>E-posta</label>
        <input v-model="email" type="email" required autofocus />
      </div>
      <div class="field">
        <label>Şifre</label>
        <input v-model="password" type="password" required />
      </div>

      <button class="btn btn-primary" type="submit" :disabled="loading" style="width: 100%">
        {{ loading ? 'Giriş yapılıyor...' : 'Giriş yap' }}
      </button>
    </form>
  </div>
</template>

<style scoped>
.login-wrap {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg);
}
.login-card {
  width: 340px;
}
.login-card h1 {
  margin: 0 0 2px;
  font-size: 22px;
}
.login-card p {
  margin: 0 0 20px;
}
</style>
