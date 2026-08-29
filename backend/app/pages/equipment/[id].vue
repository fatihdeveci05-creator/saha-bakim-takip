<script setup lang="ts">
import type { Equipment, Site } from '~/types'
import { DURUM_LABELS } from '~/types'

const route = useRoute()
const { apiFetch } = useApi()
const id = route.params.id as string

interface EquipmentHistoryEntry {
  id: number
  tip: string
  durum: string
  aciklama: string | null
  reportedAt: string | null
  resolvedAt: string | null
  resolvedByUserId: number | null
  resolvedByAd: string | null
}

const { data: item, pending, error } = await useAsyncData(`equipment-${id}`, () => apiFetch<Equipment>(`/api/equipment/${id}`))
const site = ref<Site | null>(null)
const { data: history } = await useAsyncData(`equipment-history-${id}`, () =>
  apiFetch<EquipmentHistoryEntry[]>(`/api/equipment/${id}/history`),
)

watchEffect(async () => {
  if (!item.value) return
  site.value = await apiFetch<Site>(`/api/sites/${item.value.siteId}`)
})

const tipLabels: Record<string, string> = { asansor: 'Asansör', yuruyen_merdiven: 'Yürüyen Merdiven' }
const isEmriTipLabels: Record<string, string> = { bakim: 'Bakım', ariza: 'Arıza', kontrol: 'Kontrol' }

function fmt(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleString('tr-TR')
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Ekipman #{{ id }}</h1>
      <NuxtLink class="btn" to="/saha-durumu">← Saha Durumu'na dön</NuxtLink>
    </div>

    <div v-if="error" class="error-box">Kayıt yüklenemedi</div>
    <div v-else-if="pending || !item" class="muted">Yükleniyor...</div>

    <div v-else style="display: flex; flex-direction: column; gap: 16px">
      <div class="card">
        <div style="font-weight: 600; font-size: 16px">{{ site?.ad ?? `Saha #${item.siteId}` }}</div>
        <div class="muted">{{ tipLabels[item.tip] }} — {{ item.marka }} {{ item.model }} — Seri No: {{ item.seriNo ?? '—' }}</div>
      </div>

      <div class="card">
        <h3 style="margin-top: 0">Ünite Geçmişi (Künye)</h3>
        <div v-if="!history?.length" class="muted">Bu ekipmanla ilgili henüz kayıt yok.</div>
        <div v-for="h in history" :key="h.id" style="padding: 8px 0; border-top: 1px solid var(--border)">
          <span class="badge" :class="`badge-${h.durum}`">{{ DURUM_LABELS[h.durum] }}</span>
          <span class="muted" style="margin-left: 8px">{{ isEmriTipLabels[h.tip] }} · {{ h.resolvedByAd ?? '—' }} · {{ fmt(h.resolvedAt) }}</span>
          <p v-if="h.aciklama" style="margin: 4px 0 0">{{ h.aciklama }}</p>
          <NuxtLink :to="`/work-orders/${h.id}`" style="font-size: 12px">İş emrini görüntüle →</NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>
