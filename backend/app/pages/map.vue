<script setup lang="ts">
import type { UserLocation } from '~/types'

const { apiFetch } = useApi()

const mapEl = ref<HTMLDivElement | null>(null)
let map: import('leaflet').Map | null = null
let markersLayer: import('leaflet').LayerGroup | null = null
let pollHandle: ReturnType<typeof setInterval> | null = null

async function loadAndRenderLocations(L: typeof import('leaflet')) {
  const locations = await apiFetch<UserLocation[]>('/api/locations')
  if (!map || !markersLayer) return
  markersLayer.clearLayers()
  for (const loc of locations) {
    const lat = Number(loc.lat)
    const lng = Number(loc.lng)
    if (Number.isNaN(lat) || Number.isNaN(lng)) continue
    L.marker([lat, lng])
      .bindPopup(`<b>${loc.ad}</b><br>${loc.rol}<br>${new Date(loc.updatedAt).toLocaleString('tr-TR')}`)
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
