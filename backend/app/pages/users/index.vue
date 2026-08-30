<script setup lang="ts">
import type { AppUser, Team } from '~/types'

const { apiFetch } = useApi()
const auth = useAuth()
const { data: items, pending, error, refresh } = await useAsyncData('users', () => apiFetch<AppUser[]>('/api/users'))
const { data: teamList } = await useAsyncData('teams-lookup', () => apiFetch<Team[]>('/api/teams'))
const teamNameById = computed(() => new Map((teamList.value ?? []).map((t) => [t.id, t.ad])))

const showForm = ref(false)
const form = reactive({
  ad: '',
  email: '',
  telefon: '',
  password: '',
  taraf: 'alt_yuklenici' as 'alt_yuklenici' | 'isveren',
  rol: 'ariza_ekibi',
  takimId: '',
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
    if (taraf === 'isveren') form.takimId = ''
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
        takimId: form.takimId ? Number(form.takimId) : undefined,
      },
    })
    form.ad = ''
    form.email = ''
    form.telefon = ''
    form.password = ''
    form.takimId = ''
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

const deleteError = ref('')
async function deleteUser(u: AppUser) {
  if (!confirm(`"${u.ad}" kullanıcısını silmek istediğinize emin misiniz?`)) return
  deleteError.value = ''
  try {
    await apiFetch(`/api/users/${u.id}`, { method: 'DELETE' })
    await refresh()
  } catch (err) {
    deleteError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Silinemedi'
  }
}

async function changeTeam(u: AppUser, takimId: string) {
  deleteError.value = ''
  try {
    await apiFetch(`/api/users/${u.id}`, { method: 'PATCH', body: { takimId: takimId ? Number(takimId) : null } })
    await refresh()
  } catch (err) {
    deleteError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Takım güncellenemedi'
  }
}

// Sahadaki "günlük görev ataması" — Ahmet'i bugün bakımdan arızaya/kontrole
// almak gibi. Yönetici herkesin rolünü değiştirebilir; Sorumlu (Yüklenici)
// sadece halihazırda saha personeli olan hesapları 3 saha rolü arasında
// geçirebilir (backend PATCH /api/users/:id ile aynı kısıt).
const sahaRolleri = ['ariza_ekibi', 'bakim_ekibi', 'kontrol_ekibi']
function rolDegistirilebilirMi(u: AppUser) {
  if (auth.user.value?.rol === 'yonetici') return true
  if (auth.user.value?.rol === 'sorumlu') return u.taraf === 'alt_yuklenici' && sahaRolleri.includes(u.rol)
  return false
}
function rolSecenekleri(u: AppUser) {
  if (auth.user.value?.rol === 'sorumlu') return rolOptions.alt_yuklenici.filter((r) => sahaRolleri.includes(r.value))
  return rolOptions[u.taraf] ?? []
}
async function changeRol(u: AppUser, rol: string) {
  deleteError.value = ''
  try {
    await apiFetch(`/api/users/${u.id}`, { method: 'PATCH', body: { rol } })
    await refresh()
  } catch (err) {
    deleteError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Rol güncellenemedi'
  }
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
      <div v-if="form.taraf === 'alt_yuklenici'" class="field">
        <label>Takım (isteğe bağlı)</label>
        <select v-model="form.takimId">
          <option value="">— Takım yok —</option>
          <option v-for="t in teamList" :key="t.id" :value="t.id">{{ t.ad }}</option>
        </select>
      </div>
      <button class="btn btn-primary" type="submit" :disabled="saving">Kaydet</button>
    </form>

    <div v-if="deleteError" class="error-box">{{ deleteError }}</div>
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
            <th>Takım</th>
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
            <td>
              <select
                v-if="rolDegistirilebilirMi(u)"
                :value="u.rol"
                style="width: auto"
                @change="changeRol(u, ($event.target as HTMLSelectElement).value)"
              >
                <option v-for="r in rolSecenekleri(u)" :key="r.value" :value="r.value">{{ r.label }}</option>
              </select>
              <span v-else>{{ u.rol }}</span>
            </td>
            <td>
              <select
                v-if="u.taraf === 'alt_yuklenici'"
                :value="u.takimId ?? ''"
                style="width: auto"
                @change="changeTeam(u, ($event.target as HTMLSelectElement).value)"
              >
                <option value="">— Takım yok —</option>
                <option v-for="t in teamList" :key="t.id" :value="t.id">{{ t.ad }}</option>
              </select>
              <span v-else class="muted">—</span>
            </td>
            <td>
              <span class="badge" :class="u.aktif ? 'badge-onaylandi' : 'badge-reddedildi'">{{ u.aktif ? 'Aktif' : 'Pasif' }}</span>
            </td>
            <td style="display: flex; gap: 6px">
              <button class="btn" @click="toggleAktif(u)">{{ u.aktif ? 'Pasife al' : 'Aktifleştir' }}</button>
              <button v-if="auth.user.value?.rol === 'yonetici'" class="btn btn-danger" @click="deleteUser(u)">Sil</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
