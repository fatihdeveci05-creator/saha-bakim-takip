<script setup lang="ts">
import type { AppUser } from '~/types'

const { apiFetch } = useApi()
const { data: items, pending, error, refresh } = await useAsyncData('users', () => apiFetch<AppUser[]>('/api/users'))

const showForm = ref(false)
const form = reactive({
  ad: '',
  email: '',
  telefon: '',
  password: '',
  taraf: 'alt_yuklenici' as 'alt_yuklenici' | 'isveren',
  rol: 'ariza_ekibi',
})
const formError = ref('')
const saving = ref(false)

const rolOptions: Record<string, { value: string; label: string }[]> = {
  isveren: [
    { value: 'yonetici', label: 'Yönetici' },
    { value: 'denetci', label: 'Denetçi' },
  ],
  alt_yuklenici: [
    { value: 'sorumlu', label: 'Sorumlu' },
    { value: 'ariza_ekibi', label: 'Arıza Ekibi' },
    { value: 'bakim_ekibi', label: 'Bakım Ekibi' },
    { value: 'kontrol_ekibi', label: 'Kontrol Ekibi' },
  ],
}

watch(
  () => form.taraf,
  (taraf) => {
    form.rol = rolOptions[taraf]?.[0]?.value ?? ''
  },
)

async function submit() {
  formError.value = ''
  saving.value = true
  try {
    await apiFetch('/api/users', {
      method: 'POST',
      body: {
        ad: form.ad,
        email: form.email,
        telefon: form.telefon || undefined,
        password: form.password,
        taraf: form.taraf,
        rol: form.rol,
      },
    })
    form.ad = ''
    form.email = ''
    form.telefon = ''
    form.password = ''
    showForm.value = false
    await refresh()
  } catch (err) {
    formError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Kaydedilemedi'
  } finally {
    saving.value = false
  }
}

async function toggleAktif(u: AppUser) {
  await apiFetch(`/api/users/${u.id}`, { method: 'PATCH', body: { aktif: !u.aktif } })
  await refresh()
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Kullanıcılar</h1>
      <button class="btn btn-primary" @click="showForm = !showForm">{{ showForm ? 'Vazgeç' : '+ Yeni Kullanıcı' }}</button>
    </div>

    <form v-if="showForm" class="card" style="margin-bottom: 16px" @submit.prevent="submit">
      <div v-if="formError" class="error-box">{{ formError }}</div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">
        <div class="field"><label>Ad Soyad</label><input v-model="form.ad" required /></div>
        <div class="field"><label>Telefon</label><input v-model="form.telefon" /></div>
      </div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">
        <div class="field"><label>E-posta</label><input v-model="form.email" type="email" required /></div>
        <div class="field"><label>Şifre</label><input v-model="form.password" type="password" required minlength="8" /></div>
      </div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">
        <div class="field">
          <label>Taraf</label>
          <select v-model="form.taraf">
            <option value="alt_yuklenici">Alt Yüklenici</option>
            <option value="isveren">İşveren</option>
          </select>
        </div>
        <div class="field">
          <label>Rol</label>
          <select v-model="form.rol">
            <option v-for="r in rolOptions[form.taraf]" :key="r.value" :value="r.value">{{ r.label }}</option>
          </select>
        </div>
      </div>
      <button class="btn btn-primary" type="submit" :disabled="saving">Kaydet</button>
    </form>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Kayıt yok.</div>

    <div v-else class="card" style="padding: 0">
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Ad</th>
            <th>E-posta</th>
            <th>Taraf</th>
            <th>Rol</th>
            <th>Durum</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in items" :key="u.id">
            <td>{{ u.id }}</td>
            <td>{{ u.ad }}</td>
            <td>{{ u.email }}</td>
            <td>{{ u.taraf === 'isveren' ? 'İşveren' : 'Alt Yüklenici' }}</td>
            <td>{{ u.rol }}</td>
            <td>
              <span class="badge" :class="u.aktif ? 'badge-onaylandi' : 'badge-reddedildi'">{{ u.aktif ? 'Aktif' : 'Pasif' }}</span>
            </td>
            <td>
              <button class="btn" @click="toggleAktif(u)">{{ u.aktif ? 'Pasife al' : 'Aktifleştir' }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
