<script setup lang="ts">
import type { Site } from '~/types'

const { apiFetch } = useApi()
const { data: items, pending, error, refresh } = await useAsyncData('sites', () => apiFetch<Site[]>('/api/sites'))

const showForm = ref(false)
const form = reactive({ ad: '', adres: '', lat: '', lng: '' })
const formError = ref('')
const saving = ref(false)

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
      <button class="btn btn-primary" @click="showForm = !showForm">{{ showForm ? 'Vazgeç' : '+ Yeni Saha' }}</button>
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
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in items" :key="s.id">
            <td>{{ s.id }}</td>
            <td>{{ s.ad }}</td>
            <td>{{ s.adres ?? '—' }}</td>
            <td>{{ s.lat && s.lng ? `${s.lat}, ${s.lng}` : '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
