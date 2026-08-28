<script setup lang="ts">
import type { Equipment, Site } from '~/types'

const { apiFetch } = useApi()
const { data: items, pending, error, refresh } = await useAsyncData('equipment', () => apiFetch<Equipment[]>('/api/equipment'))
const { data: sites } = await useAsyncData('sites-for-equipment', () => apiFetch<Site[]>('/api/sites'))
const siteNameById = computed(() => new Map((sites.value ?? []).map((s) => [s.id, s.ad])))

const showForm = ref(false)
const form = reactive({ siteId: '', tip: 'asansor', marka: '', model: '', seriNo: '' })
const formError = ref('')
const saving = ref(false)

async function submit() {
  formError.value = ''
  saving.value = true
  try {
    await apiFetch('/api/equipment', {
      method: 'POST',
      body: {
        siteId: Number(form.siteId),
        tip: form.tip,
        marka: form.marka || undefined,
        model: form.model || undefined,
        seriNo: form.seriNo || undefined,
      },
    })
    form.siteId = ''
    form.marka = ''
    form.model = ''
    form.seriNo = ''
    showForm.value = false
    await refresh()
  } catch (err) {
    formError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Kaydedilemedi'
  } finally {
    saving.value = false
  }
}

const tipLabels: Record<string, string> = { asansor: 'Asansör', yuruyen_merdiven: 'Yürüyen Merdiven' }
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Ekipmanlar</h1>
      <button class="btn btn-primary" @click="showForm = !showForm">{{ showForm ? 'Vazgeç' : '+ Yeni Ekipman' }}</button>
    </div>

    <form v-if="showForm" class="card" style="margin-bottom: 16px" @submit.prevent="submit">
      <div v-if="formError" class="error-box">{{ formError }}</div>
      <div class="field">
        <label>Saha</label>
        <select v-model="form.siteId" required>
          <option value="" disabled>Seçin</option>
          <option v-for="s in sites" :key="s.id" :value="s.id">{{ s.ad }}</option>
        </select>
      </div>
      <div class="field">
        <label>Tip</label>
        <select v-model="form.tip">
          <option value="asansor">Asansör</option>
          <option value="yuruyen_merdiven">Yürüyen Merdiven</option>
        </select>
      </div>
      <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px">
        <div class="field"><label>Marka</label><input v-model="form.marka" /></div>
        <div class="field"><label>Model</label><input v-model="form.model" /></div>
        <div class="field"><label>Seri No</label><input v-model="form.seriNo" /></div>
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
            <th>Saha</th>
            <th>Tip</th>
            <th>Marka/Model</th>
            <th>Seri No</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="e in items" :key="e.id">
            <td>{{ e.id }}</td>
            <td>{{ siteNameById.get(e.siteId) ?? `#${e.siteId}` }}</td>
            <td>{{ tipLabels[e.tip] }}</td>
            <td>{{ e.marka }} {{ e.model }}</td>
            <td>{{ e.seriNo ?? '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
