<script setup lang="ts">
import type { UserLocation } from '~/types'

const { apiFetch } = useApi()

const mapEl = ref<HTMLDivElement | null>(null)
let map: import('leaflet').Map | null = null
let markersLayer: import('leaflet').LayerGroup | null = null
let pollHandle: ReturnType<typeof setInterval> | null = null
let hasFitBoundsOnce = false

// Ekip rolüne göre marker rengi — mobildeki TipBadge renkleriyle tutarlı.
const ROL_RENKLERI: Record<string, string> = {
  ariza_ekibi: '#dc2626',
  bakim_ekibi: '#4f46e5',
  kontrol_ekibi: '#0d9488',
}
const VARSAYILAN_RENK = '#2563eb'

function formatRelativeTime(iso: string) {
  const diffMs = Date.now() - new Date(iso).getTime()
  const diffMin = Math.floor(diffMs / 60_000)
  if (diffMin < 1) return 'az önce'
  if (diffMin < 60) return `${diffMin} dk önce`
  const diffSaat = Math.floor(diffMin / 60)
  if (diffSaat < 24) return `${diffSaat} sa önce`
  const diffGun = Math.floor(diffSaat / 24)
  return `${diffGun} gün önce`
}

async function loadAndRenderLocations(L: typeof import('leaflet')) {
  const locations = await apiFetch<UserLocation[]>('/api/locations')
  if (!map || !markersLayer) return
  markersLayer.clearLayers()
  const points: [number, number][] = []
  for (const loc of locations) {
    const lat = Number(loc.lat)
    const lng = Number(loc.lng)
    if (Number.isNaN(lat) || Number.isNaN(lng)) continue
    points.push([lat, lng])
    L.circleMarker([lat, lng], {
      radius: 10,
      color: '#fff',
      weight: 2,
      fillColor: ROL_RENKLERI[loc.rol] ?? VARSAYILAN_RENK,
      fillOpacity: 0.9,
    })
      .bindPopup(`<b>${loc.ad}</b><br>${loc.rol}<br>Son konum: ${formatRelativeTime(loc.updatedAt)}`)
      .addTo(markersLayer)
  }
  // Sabit İstanbul merkez/zoom yerine tüm noktaları kapsayacak şekilde
  // otomatik yakınlaştır — ama sadece ilk yüklemede, kullanıcı sonradan
  // haritada gezinirse periyodik yenilemede görünümü sıfırlama.
  if (!hasFitBoundsOnce && points.length) {
    hasFitBoundsOnce = true
    if (points.length === 1) {
      map.setView(points[0], 15)
    } else {
      map.fitBounds(L.latLngBounds(points), { padding: [40, 40], maxZoom: 15 })
    }
  }
}

onMounted(async () => {
  const L = await import('leaflet')

  if (!mapEl.value) return
  map = L.map(mapEl.value).setView([41.05, 28.8], 12)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap katkıda bulunanlar',
  }).addTo(map)
  markersLayer = L.layerGroup().addTo(map)

  await loadAndRenderLocations(L)
  pollHandle = setInterval(() => loadAndRenderLocations(L), 60_000)
})

onUnmounted(() => {
  if (pollHandle) clearInterval(pollHandle)
  map?.remove()
})
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Canlı Harita</h1>
      <span class="muted">Konumlar 1 dakikada bir güncellenir</span>
    </div>
    <div ref="mapEl" style="height: 70vh; border-radius: 8px; border: 1px solid var(--border)"></div>
  </div>
</template>
