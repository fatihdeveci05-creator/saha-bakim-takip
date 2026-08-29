<script setup lang="ts">
import type { WorkOrder, AppUser, Team } from '~/types'

const { apiFetch } = useApi()

const { data: workOrders, pending, error } = await useAsyncData('dashboard-work-orders', () =>
  apiFetch<WorkOrder[]>('/api/work-orders'),
)

// "Bugünün ekip dağılımı" — hangi personelin hangi rolde/ekipte olduğu
// ayrı bir tarihli kayıt değil, sadece güncel (mutable) users.rol/takimId
// (bkz. PLAN.md "günlük görev ataması") — o yüzden burada gösterilen zaten
// "bugün" demek, ayrı bir geçmiş sorgusu yok.
const { data: personelList } = await useAsyncData('dashboard-personel', () => apiFetch<AppUser[]>('/api/users'))
const { data: teamList } = await useAsyncData('dashboard-teams', () => apiFetch<Team[]>('/api/teams'))
const teamNameById = computed(() => new Map((teamList.value ?? []).map((t) => [t.id, t.ad])))

const rolLabels: Record<string, string> = {
  sorumlu: 'Sorumlu',
  ariza_ekibi: 'Arıza Ekibi',
  bakim_ekibi: 'Bakım Ekibi',
  kontrol_ekibi: 'Kontrol Ekibi',
}
const rolSirasi = ['sorumlu', 'ariza_ekibi', 'bakim_ekibi', 'kontrol_ekibi']

const ekipDagilimi = computed(() => {
  const aktifSahaPersoneli = (personelList.value ?? []).filter((u) => u.taraf === 'alt_yuklenici' && u.aktif)
  return rolSirasi
    .map((rol) => ({
      rol,
      label: rolLabels[rol],
      kisiler: aktifSahaPersoneli.filter((u) => u.rol === rol),
    }))
    .filter((g) => g.kisiler.length)
})

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
      <h2 style="font-size: 16px; margin: 0 0 12px">Bugünün Ekip Dağılımı</h2>
      <div v-if="!ekipDagilimi.length" class="muted">Aktif saha personeli yok.</div>
      <div v-else style="display: flex; flex-direction: column; gap: 12px">
        <div v-for="g in ekipDagilimi" :key="g.rol">
          <div class="muted" style="font-size: 12px; font-weight: 600; margin-bottom: 4px">{{ g.label }} ({{ g.kisiler.length }})</div>
          <div style="display: flex; flex-wrap: wrap; gap: 6px">
            <span
              v-for="u in g.kisiler"
              :key="u.id"
              style="background: var(--bg); border: 1px solid var(--border); border-radius: 999px; padding: 3px 10px; font-size: 12px"
            >
              {{ u.ad }} <span v-if="u.takimId" class="muted">({{ teamNameById.get(u.takimId) ?? '—' }})</span>
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <p class="muted" style="margin: 0">
        Onay bekleyen işleri incelemek için <NuxtLink to="/denetim">Denetim Kuyruğu</NuxtLink> sayfasına gidin.
      </p>
    </div>
  </div>
</template>
