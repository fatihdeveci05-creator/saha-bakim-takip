<script setup lang="ts">
import type { Team, AppUser } from '~/types'

const { apiFetch } = useApi()
const auth = useAuth()
const { data: items, pending, error, refresh } = await useAsyncData('teams', () => apiFetch<Team[]>('/api/teams'))
const deleteError = ref('')

async function deleteTeam(t: Team) {
  if (!confirm(`"${t.ad}" ekibini silmek istediğinize emin misiniz?`)) return
  deleteError.value = ''
  try {
    await apiFetch(`/api/teams/${t.id}`, { method: 'DELETE' })
    await refresh()
  } catch (err) {
    deleteError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Silinemedi'
  }
}
const { data: userList } = await useAsyncData('users-for-teams', () => apiFetch<AppUser[]>('/api/users'))

const membersByTeam = computed(() => {
  const map = new Map<number, AppUser[]>()
  for (const u of userList.value ?? []) {
    if (u.takimId == null) continue
    if (!map.has(u.takimId)) map.set(u.takimId, [])
    map.get(u.takimId)!.push(u)
  }
  return map
})

const showForm = ref(false)
const form = reactive({ ad: '', tip: 'ariza' })
const formError = ref('')
const saving = ref(false)

async function submit() {
  formError.value = ''
  saving.value = true
  try {
    await apiFetch('/api/teams', { method: 'POST', body: { ad: form.ad, tip: form.tip } })
    form.ad = ''
    showForm.value = false
    await refresh()
  } catch (err) {
    formError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Kaydedilemedi'
  } finally {
    saving.value = false
  }
}

const tipLabels: Record<string, string> = { ariza: 'Arıza', bakim: 'Bakım', kontrol: 'Kontrol' }
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Ekipler</h1>
      <button class="btn btn-primary" @click="showForm = !showForm">{{ showForm ? 'Vazgeç' : '+ Yeni Ekip' }}</button>
    </div>

    <form v-if="showForm" class="card" style="margin-bottom: 16px" @submit.prevent="submit">
      <div v-if="formError" class="error-box">{{ formError }}</div>
      <div class="field"><label>Ad</label><input v-model="form.ad" required /></div>
      <div class="field">
        <label>Tip</label>
        <select v-model="form.tip">
          <option value="ariza">Arıza</option>
          <option value="bakim">Bakım</option>
          <option value="kontrol">Kontrol</option>
        </select>
      </div>
      <button class="btn btn-primary" type="submit" :disabled="saving">Kaydet</button>
    </form>

    <p class="muted" style="margin: 0 0 12px; font-size: 13px">
      Üye eklemek/çıkarmak için <NuxtLink to="/users">Kullanıcılar</NuxtLink> sayfasındaki "Takım" sütununu kullanın.
      "Sorumlu" rolündeki bir kullanıcı, iş atarken sadece kendi ekibindeki personeli görür ve seçebilir.
    </p>

    <div v-if="deleteError" class="error-box">{{ deleteError }}</div>
    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Kayıt yok.</div>

    <div v-else style="display: flex; flex-direction: column; gap: 12px">
      <div v-for="t in items" :key="t.id" class="card">
        <div style="display: flex; justify-content: space-between; align-items: start">
          <div>
            <div style="font-weight: 600">{{ t.ad }}</div>
            <div class="muted" style="font-size: 13px">{{ tipLabels[t.tip] }}</div>
          </div>
          <div style="display: flex; align-items: center; gap: 8px">
            <span class="badge badge-bekliyor">{{ (membersByTeam.get(t.id) ?? []).length }} üye</span>
            <button v-if="auth.user.value?.rol === 'yonetici'" class="btn btn-danger" @click="deleteTeam(t)">Sil</button>
          </div>
        </div>
        <div v-if="(membersByTeam.get(t.id) ?? []).length" style="margin-top: 10px; display: flex; flex-wrap: wrap; gap: 6px">
          <span
            v-for="u in membersByTeam.get(t.id)"
            :key="u.id"
            style="background: var(--bg); border: 1px solid var(--border); border-radius: 999px; padding: 3px 10px; font-size: 12px"
          >
            {{ u.ad }} <span class="muted">({{ u.rol }})</span>
          </span>
        </div>
        <p v-else class="muted" style="margin: 10px 0 0; font-size: 13px">Henüz üye yok.</p>
      </div>
    </div>
  </div>
</template>
