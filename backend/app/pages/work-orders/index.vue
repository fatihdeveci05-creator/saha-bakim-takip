<script setup lang="ts">
import type { WorkOrder, Equipment, Site, Durum } from '~/types'
import { DURUM_LABELS } from '~/types'

const { apiFetch } = useApi()

const durumFilter = ref<Durum | ''>('')

const { data: items, pending, error, refresh } = await useAsyncData(
  'work-orders-list',
  () => apiFetch<WorkOrder[]>(`/api/work-orders${durumFilter.value ? `?durum=${durumFilter.value}` : ''}`),
  { watch: [durumFilter] },
)

const { data: equipmentList } = await useAsyncData('equipment-lookup', () => apiFetch<Equipment[]>('/api/equipment'))
const { data: siteList } = await useAsyncData('sites-lookup', () => apiFetch<Site[]>('/api/sites'))

const siteNameById = computed(() => new Map((siteList.value ?? []).map((s) => [s.id, s.ad])))
const equipmentById = computed(() => new Map((equipmentList.value ?? []).map((e) => [e.id, e])))

function equipmentLabel(equipmentId: number) {
  const eq = equipmentById.value.get(equipmentId)
  if (!eq) return `#${equipmentId}`
  const siteName = siteNameById.value.get(eq.siteId) ?? `Saha #${eq.siteId}`
  return `${siteName} — ${eq.marka ?? ''} ${eq.model ?? ''}`.trim()
}

const tipLabels: Record<string, string> = { bakim: 'Bakım', ariza: 'Arıza', kontrol: 'Kontrol' }

function fmt(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleString('tr-TR')
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>İş Emirleri</h1>
      <select v-model="durumFilter" style="width: auto">
        <option value="">Tüm durumlar</option>
        <option v-for="(label, key) in DURUM_LABELS" :key="key" :value="key">{{ label }}</option>
      </select>
    </div>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Kayıt yok.</div>

    <div v-else class="card" style="padding: 0">
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Ekipman / Saha</th>
            <th>Tip</th>
            <th>Durum</th>
            <th>Bildirim</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="wo in items" :key="wo.id">
            <td>{{ wo.id }}</td>
            <td>{{ equipmentLabel(wo.equipmentId) }}</td>
            <td>{{ tipLabels[wo.tip] }}</td>
            <td><span class="badge" :class="`badge-${wo.durum}`">{{ DURUM_LABELS[wo.durum] }}</span></td>
            <td>{{ fmt(wo.reportedAt) }}</td>
            <td>
              <NuxtLink class="btn" :to="`/work-orders/${wo.id}`">Detay</NuxtLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
