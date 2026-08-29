<script setup lang="ts">
interface SiteStatusEquipment {
  id: number
  tip: string
  marka: string | null
  model: string | null
  seriNo: string | null
  durum: 'kirmizi' | 'sari' | 'yesil'
}
interface SiteStatus {
  id: number
  ad: string
  lat: string | null
  lng: string | null
  durum: 'kirmizi' | 'sari' | 'yesil'
  equipment: SiteStatusEquipment[]
}

const { apiFetch } = useApi()
const { data: items, pending, error, refresh } = await useAsyncData('saha-durumu', () => apiFetch<SiteStatus[]>('/api/sites/status'))

const tipLabels: Record<string, string> = { asansor: 'Asansör', yuruyen_merdiven: 'Yürüyen Merdiven' }
const renkLabels: Record<string, string> = { kirmizi: 'Sorun var', sari: 'Bakımda', yesil: 'Sorun yok' }

const acikId = ref<number | null>(null)
function toggle(id: number) {
  acikId.value = acikId.value === id ? null : id
}

onActivated(() => refresh())
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Saha Durumu</h1>
      <button class="btn" @click="refresh()">Yenile</button>
    </div>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Saha yok.</div>

    <div v-else style="display: flex; flex-direction: column; gap: 10px">
      <div v-for="site in items" :key="site.id" class="card" style="padding: 0; overflow: hidden">
        <button
          style="width: 100%; text-align: left; display: flex; align-items: center; justify-content: space-between; padding: 14px 16px; background: none; border: none; cursor: pointer; font: inherit; color: inherit"
          @click="toggle(site.id)"
        >
          <div style="display: flex; align-items: center; gap: 10px">
            <span :class="`durum-dot durum-${site.durum}`" />
            <span style="font-weight: 600">{{ site.ad }}</span>
            <span class="muted" style="font-size: 12px">{{ renkLabels[site.durum] }} · {{ site.equipment.length }} ünite</span>
          </div>
          <span class="muted">{{ acikId === site.id ? '▲' : '▼' }}</span>
        </button>

        <div v-if="acikId === site.id" style="border-top: 1px solid var(--border); padding: 4px 16px 12px">
          <div v-if="!site.equipment.length" class="muted" style="padding: 8px 0">Bu sahada ekipman yok.</div>
          <NuxtLink
            v-for="eq in site.equipment"
            :key="eq.id"
            :to="`/equipment/${eq.id}`"
            style="display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid var(--border); color: inherit; text-decoration: none"
          >
            <span :class="`durum-dot durum-${eq.durum}`" />
            <span>{{ tipLabels[eq.tip] }} — {{ eq.marka }} {{ eq.model }}</span>
            <span class="muted" style="font-size: 12px">{{ eq.seriNo ?? '—' }}</span>
            <span class="muted" style="margin-left: auto; font-size: 12px">{{ renkLabels[eq.durum] }} →</span>
          </NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.durum-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.durum-kirmizi {
  background: #dc2626;
}
.durum-sari {
  background: #d97706;
}
.durum-yesil {
  background: #16a34a;
}
</style>
