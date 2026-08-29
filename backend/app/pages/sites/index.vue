<script setup lang="ts">
import type { Site } from '~/types'

const { apiFetch } = useApi()
const auth = useAuth()
const showInactive = ref(false)
const { data: items, pending, error, refresh } = await useAsyncData(
  'sites',
  () => apiFetch<Site[]>(`/api/sites${showInactive.value ? '?includeInactive=1' : ''}`),
  { watch: [showInactive] },
)

const showForm = ref(false)
const form = reactive({ ad: '', adres: '', lat: '', lng: '' })
const formError = ref('')
const saving = ref(false)
const deleteError = ref('')

async function toggleAktif(s: Site) {
  await apiFetch(`/api/sites/${s.id}`, { method: 'PATCH', body: { aktif: !s.aktif } })
  await refresh()
}

async function deleteSite(s: Site) {
  if (!confirm(`"${s.ad}" sahasını silmek istediğinize emin misiniz?`)) return
  deleteError.value = ''
  try {
    await apiFetch(`/api/sites/${s.id}`, { method: 'DELETE' })
    await refresh()
  } catch (err) {
    deleteError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Silinemedi'
  }
}

async function submit() {
  formError.value = ''
  saving.value = true
  try {
    await apiFetch('/api/sites', {
      method: 'POST',
      body: {
        ad: form.ad,
        adres: form.adres || undefined,
        lat: form.lat ? Number(form.lat) : undefined,
        lng: form.lng ? Number(form.lng) : undefined,
      },
    })
    form.ad = ''
    form.adres = ''
    form.lat = ''
    form.lng = ''
    showForm.value = false
    await refresh()
  } catch (err) {
    formError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Kaydedilemedi'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Sahalar</h1>
      <div style="display: flex; align-items: center; gap: 12px">
        <label style="display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: normal">
          <input v-model="showInactive" type="checkbox" /> Pasifleri göster
        </label>
        <button class="btn btn-primary" @click="showForm = !showForm">{{ showForm ? 'Vazgeç' : '+ Yeni Saha' }}</button>
      </div>
    </div>

    <form v-if="showForm" class="card" style="margin-bottom: 16px" @submit.prevent="submit">
      <div v-if="formError" class="error-box">{{ formError }}</div>
      <div class="field"><label>Ad</label><input v-model="form.ad" required /></div>
      <div class="field"><label>Adres</label><input v-model="form.adres" /></div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">
        <div class="field"><label>Lat</label><input v-model="form.lat" type="number" step="any" /></div>
        <div class="field"><label>Lng</label><input v-model="form.lng" type="number" step="any" /></div>
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
            <th>Adres</th>
            <th>Konum</th>
            <th>Durum</th>
            <th v-if="auth.user.value?.rol === 'yonetici'"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in items" :key="s.id">
            <td>{{ s.id }}</td>
            <td>{{ s.ad }}</td>
            <td>{{ s.adres ?? '—' }}</td>
            <td>{{ s.lat && s.lng ? `${s.lat}, ${s.lng}` : '—' }}</td>
            <td><span class="badge" :class="s.aktif ? 'badge-onaylandi' : 'badge-reddedildi'">{{ s.aktif ? 'Aktif' : 'Pasif' }}</span></td>
            <td v-if="auth.user.value?.rol === 'yonetici'" style="display: flex; gap: 6px">
              <button class="btn" @click="toggleAktif(s)">{{ s.aktif ? 'Pasife al' : 'Aktifleştir' }}</button>
              <button class="btn btn-danger" @click="deleteSite(s)">Sil</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
