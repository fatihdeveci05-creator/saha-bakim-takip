<script setup lang="ts">
import type { WorkOrder } from '~/types'

const { apiFetch } = useApi()

const { data: workOrders, pending, error } = await useAsyncData('dashboard-work-orders', () =>
  apiFetch<WorkOrder[]>('/api/work-orders'),
)

const acikIsSayisi = computed(
  () => workOrders.value?.filter((w) => ['bekliyor', 'devam_edecek', 'onay_bekliyor'].includes(w.durum)).length ?? 0,
)
const onayBekleyenSayisi = computed(() => workOrders.value?.filter((w) => w.durum === 'onay_bekliyor').length ?? 0)

function avgHours(getStart: (w: WorkOrder) => string | null, getEnd: (w: WorkOrder) => string | null) {
  const list = workOrders.value ?? []
  const diffs = list
    .map((w) => {
      const start = getStart(w)
      const end = getEnd(w)
      if (!start || !end) return null
      return (new Date(end).getTime() - new Date(start).getTime()) / 3_600_000
    })
    .filter((v): v is number => v !== null && v >= 0)
  if (!diffs.length) return null
  return diffs.reduce((a, b) => a + b, 0) / diffs.length
}

const ortalamaMudahaleSaat = computed(() => avgHours((w) => w.reportedAt, (w) => w.responseStartedAt))
const ortalamaCozumSaat = computed(() => avgHours((w) => w.reportedAt, (w) => w.resolvedAt))

// Basit gecikme sezgisi: 3 günden uzun süredir açık durumda olanlar (SLA hedefi henüz tanımlı değil)
const gecikenIsler = computed(() => {
  const cutoff = Date.now() - 3 * 24 * 3_600_000
  return (
    workOrders.value?.filter(
      (w) => ['bekliyor', 'devam_edecek'].includes(w.durum) && new Date(w.createdAt).getTime() < cutoff,
    ).length ?? 0
  )
})

function fmtHours(v: number | null) {
  if (v === null) return '—'
  return `${v.toFixed(1)} sa`
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Dashboard</h1>
    </div>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>

    <div v-else class="stat-grid">
      <div class="stat-card">
        <div class="value">{{ acikIsSayisi }}</div>
        <div class="label">Açık iş sayısı</div>
      </div>
      <div class="stat-card">
        <div class="value">{{ onayBekleyenSayisi }}</div>
        <div class="label">Onay bekleyen</div>
      </div>
      <div class="stat-card">
        <div class="value">{{ fmtHours(ortalamaMudahaleSaat) }}</div>
        <div class="label">Ort. müdahale süresi</div>
      </div>
      <div class="stat-card">
        <div class="value">{{ fmtHours(ortalamaCozumSaat) }}</div>
        <div class="label">Ort. çözüm süresi</div>
      </div>
      <div class="stat-card">
        <div class="value">{{ gecikenIsler }}</div>
        <div class="label">Geciken işler (&gt;3 gün)</div>
      </div>
    </div>

    <div class="card">
      <p class="muted" style="margin: 0">
        Onay bekleyen işleri incelemek için <NuxtLink to="/denetim">Denetim Kuyruğu</NuxtLink> sayfasına gidin.
      </p>
    </div>
  </div>
</template>
