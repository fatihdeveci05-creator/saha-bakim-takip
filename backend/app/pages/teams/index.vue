<script setup lang="ts">
import type { Team } from '~/types'

const { apiFetch } = useApi()
const { data: items, pending, error, refresh } = await useAsyncData('teams', () => apiFetch<Team[]>('/api/teams'))

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

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Kayıt yok.</div>

    <div v-else class="card" style="padding: 0">
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Ad</th>
            <th>Tip</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in items" :key="t.id">
            <td>{{ t.id }}</td>
            <td>{{ t.ad }}</td>
            <td>{{ tipLabels[t.tip] }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
