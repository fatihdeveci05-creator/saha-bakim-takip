<script setup lang="ts">
import type { WorkOrderDetail, Equipment, Site } from '~/types'
import { DURUM_LABELS } from '~/types'

const route = useRoute()
const { apiFetch } = useApi()
const id = route.params.id as string

const { data: wo, pending, error, refresh } = await useAsyncData(`work-order-${id}`, () =>
  apiFetch<WorkOrderDetail>(`/api/work-orders/${id}`),
)

const equipment = ref<Equipment | null>(null)
const site = ref<Site | null>(null)

watchEffect(async () => {
  if (!wo.value) return
  equipment.value = await apiFetch<Equipment>(`/api/equipment/${wo.value.equipmentId}`)
  if (equipment.value) {
    site.value = await apiFetch<Site>(`/api/sites/${equipment.value.siteId}`)
  }
})

const tipLabels: Record<string, string> = { bakim: 'Bakım', ariza: 'Arıza', kontrol: 'Kontrol' }

function fmt(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleString('tr-TR')
}

const gerekce = ref('')
const reviewError = ref('')
const reviewing = ref(false)

async function submitReview(sonuc: 'onay' | 'red') {
  reviewError.value = ''
  if (sonuc === 'red' && !gerekce.value.trim()) {
    reviewError.value = 'Red için gerekçe zorunludur'
    return
  }
  reviewing.value = true
  try {
    await apiFetch(`/api/work-orders/${id}/review`, {
      method: 'POST',
      body: { sonuc, gerekce: gerekce.value.trim() || undefined },
    })
    gerekce.value = ''
    await refresh()
  } catch (err) {
    reviewError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'İşlem başarısız'
  } finally {
    reviewing.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>İş Emri #{{ id }}</h1>
      <NuxtLink class="btn" to="/work-orders">← Listeye dön</NuxtLink>
    </div>

    <div v-if="error" class="error-box">Kayıt yüklenemedi</div>
    <div v-else-if="pending || !wo" class="muted">Yükleniyor...</div>

    <div v-else style="display: flex; flex-direction: column; gap: 16px">
      <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: start">
          <div>
            <div style="font-weight: 600; font-size: 16px">{{ site?.ad ?? `Saha #${equipment?.siteId ?? '?'}` }}</div>
            <div class="muted">{{ equipment?.marka }} {{ equipment?.model }} — {{ equipment?.seriNo }}</div>
          </div>
          <span class="badge" :class="`badge-${wo.durum}`">{{ DURUM_LABELS[wo.durum] }}</span>
        </div>
        <div style="margin-top: 12px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; font-size: 13px">
          <div><span class="muted">Tip:</span> {{ tipLabels[wo.tip] }}</div>
          <div><span class="muted">Bildirim:</span> {{ fmt(wo.reportedAt) }}</div>
          <div><span class="muted">Müdahale başlangıcı:</span> {{ fmt(wo.responseStartedAt) }}</div>
          <div><span class="muted">Çözüldü:</span> {{ fmt(wo.resolvedAt) }}</div>
          <div v-if="wo.parentWorkOrderId">
            <span class="muted">Bağlı olduğu iş:</span>
            <NuxtLink :to="`/work-orders/${wo.parentWorkOrderId}`">#{{ wo.parentWorkOrderId }}</NuxtLink>
          </div>
        </div>
        <p v-if="wo.aciklama" style="margin: 12px 0 0">{{ wo.aciklama }}</p>
      </div>

      <div class="card">
        <h3 style="margin-top: 0">Fotoğraflar ({{ wo.photos.length }})</h3>
        <div v-if="!wo.photos.length" class="muted">Henüz fotoğraf eklenmemiş.</div>
        <div v-else style="display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 10px">
          <div v-for="p in wo.photos" :key="p.id" style="border: 1px solid var(--border); border-radius: 8px; overflow: hidden">
            <img :src="p.url" style="width: 100%; height: 110px; object-fit: cover; display: block; background: var(--bg)" />
            <div style="padding: 6px 8px; font-size: 11px" class="muted">
              {{ p.gpsLat }}, {{ p.gpsLng }}<br />
              {{ fmt(p.cekimZamani) }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="wo.durum === 'onay_bekliyor'" class="card">
        <h3 style="margin-top: 0">Denetim Kararı</h3>
        <div v-if="reviewError" class="error-box">{{ reviewError }}</div>
        <div class="field">
          <label>Gerekçe (red için zorunlu)</label>
          <textarea v-model="gerekce" rows="2"></textarea>
        </div>
        <div style="display: flex; gap: 10px">
          <button class="btn btn-success" :disabled="reviewing" @click="submitReview('onay')">Onayla</button>
          <button class="btn btn-danger" :disabled="reviewing" @click="submitReview('red')">Reddet</button>
        </div>
      </div>

      <div class="card" v-if="wo.reviews.length">
        <h3 style="margin-top: 0">Denetim Geçmişi</h3>
        <div v-for="r in wo.reviews" :key="r.id" style="padding: 8px 0; border-top: 1px solid var(--border)">
          <span class="badge" :class="r.sonuc === 'onay' ? 'badge-onaylandi' : 'badge-reddedildi'">{{ r.sonuc === 'onay' ? 'Onay' : 'Red' }}</span>
          <span class="muted" style="margin-left: 8px">{{ fmt(r.incelenenZaman) }}</span>
          <p v-if="r.gerekce" style="margin: 4px 0 0">{{ r.gerekce }}</p>
        </div>
      </div>

      <div class="card">
        <h3 style="margin-top: 0">Zaman Çizelgesi</h3>
        <div v-for="t in wo.timeline" :key="t.id" style="padding: 6px 0; border-top: 1px solid var(--border); font-size: 13px">
          <span class="badge" :class="`badge-${t.durum}`">{{ DURUM_LABELS[t.durum] }}</span>
          <span class="muted" style="margin-left: 8px">{{ fmt(t.createdAt) }}</span>
          <span v-if="t.not" style="margin-left: 8px">{{ t.not }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
