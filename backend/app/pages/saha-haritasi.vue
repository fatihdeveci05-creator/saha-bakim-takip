<script setup lang="ts">
interface SiteStatus {
  id: number
  ad: string
  lat: string | null
  lng: string | null
  durum: 'kirmizi' | 'sari' | 'yesil'
  equipment: { id: number; tip: string; durum: string }[]
}

const { apiFetch } = useApi()

const mapEl = ref<HTMLDivElement | null>(null)
let map: import('leaflet').Map | null = null
let markersLayer: import('leaflet').LayerGroup | null = null
let pollHandle: ReturnType<typeof setInterval> | null = null

const RENK_HEX: Record<string, string> = { kirmizi: '#dc2626', sari: '#d97706', yesil: '#16a34a' }
const RENK_LABEL: Record<string, string> = { kirmizi: 'Sorun var', sari: 'Bakımda', yesil: 'Sorun yok' }

async function loadAndRenderSites(L: typeof import('leaflet')) {
  const sitesData = await apiFetch<SiteStatus[]>('/api/sites/status')
  if (!map || !markersLayer) return
  markersLayer.clearLayers()
  for (const site of sitesData) {
    const lat = Number(site.lat)
    const lng = Number(site.lng)
    if (Number.isNaN(lat) || Number.isNaN(lng)) continue
    L.circleMarker([lat, lng], {
      radius: 12,
      color: '#fff',
      weight: 2,
      fillColor: RENK_HEX[site.durum],
      fillOpacity: 1,
    })
      .bindPopup(
        `<b>${site.ad}</b><br>${RENK_LABEL[site.durum]}<br>${site.equipment.length} ünite<br><a href="/saha-durumu">Detay için Saha Durumu →</a>`,
      )
      .addTo(markersLayer)
  }
}

onMounted(async () => {
  const L = await import('leaflet')
  const markerIcon2x = (await import('leaflet/dist/images/marker-icon-2x.png')).default
  const markerIcon = (await import('leaflet/dist/images/marker-icon.png')).default
  const markerShadow = (await import('leaflet/dist/images/marker-shadow.png')).default

  delete (L.Icon.Default.prototype as unknown as { _getIconUrl?: unknown })._getIconUrl
  L.Icon.Default.mergeOptions({
    iconRetinaUrl: markerIcon2x,
    iconUrl: markerIcon,
    shadowUrl: markerShadow,
  })

  if (!mapEl.value) return
  map = L.map(mapEl.value).setView([41.05, 28.8], 12)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap katkıda bulunanlar',
  }).addTo(map)
  markersLayer = L.layerGroup().addTo(map)

  await loadAndRenderSites(L)
  pollHandle = setInterval(() => loadAndRenderSites(L), 60_000)
})

onUnmounted(() => {
  if (pollHandle) clearInterval(pollHandle)
  map?.remove()
})
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Saha Haritası</h1>
      <span class="muted">Kırmızı: sorun var · Sarı: bakımda · Yeşil: sorun yok</span>
    </div>
    <div ref="mapEl" style="height: 70vh; border-radius: 8px; border: 1px solid var(--border)"></div>
  </div>
</template>
