<script setup lang="ts">
import type { ReportsData } from '~/types'
import { PERIOD_LABELS } from '~/utils/dateRange'

const { apiFetch } = useApi()

const { period: periodFilter, customFrom, customTo, queryString } = useDateFilter()

const { data, pending, error, refresh } = await useAsyncData(
  'reports',
  () => {
    const qs = queryString.value
    return apiFetch<ReportsData>(`/api/reports${qs ? `?${qs}` : ''}`)
  },
  { watch: [queryString] },
)
const exporting = ref(false)

function fmtSaat(v: number | null) {
  if (v === null) return '—'
  return `${v.toFixed(1)} sa`
}

function fmtOran(v: number | null) {
  if (v === null) return '—'
  return `%${(v * 100).toFixed(0)}`
}

async function exportExcel() {
  if (!data.value) return
  exporting.value = true
  try {
    const periodSlug =
      periodFilter.value === 'ozel' ? `${customFrom.value || 'bas'}_${customTo.value || 'son'}` : periodFilter.value || 'tum-zamanlar'
    await downloadExcel(`abb-kontrol-raporlar-${periodSlug}-${new Date().toISOString().slice(0, 10)}.xlsx`, [
      {
        name: 'Personel Performansı',
        headers: ['Personel', 'Atanan İş', 'Onaylanan', 'Reddedilen', 'Ort. Müdahale (sa)', 'Ort. Çözüm (sa)'],
        rows: data.value.personelPerformans.map((p) => [
          p.ad,
          p.atananSayisi,
          p.onaylananSayisi,
          p.reddedilenSayisi,
          p.ortMudahaleSaat !== null ? Number(p.ortMudahaleSaat.toFixed(2)) : null,
          p.ortCozumSaat !== null ? Number(p.ortCozumSaat.toFixed(2)) : null,
        ]),
      },
      {
        name: 'Red Oranı',
        headers: ['Personel', 'Toplam Denetim', 'Red', 'Red Oranı (%)'],
        rows: data.value.redOrani.byUser.map((u) => [u.ad, u.toplamDenetim, u.red, u.oran !== null ? Number((u.oran * 100).toFixed(1)) : null]),
      },
      {
        name: 'Malzeme Tüketimi',
        headers: ['Malzeme', 'Birim', 'Toplam Miktar'],
        rows: data.value.malzemeTuketimi.map((m) => [m.ad, m.birim, Number(m.toplamMiktar.toFixed(2))]),
      },
    ])
  } finally {
    exporting.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Raporlar</h1>
      <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap">
        <select v-model="periodFilter" style="width: auto">
          <option v-for="(label, key) in PERIOD_LABELS" :key="key" :value="key">{{ label }}</option>
        </select>
        <template v-if="periodFilter === 'ozel'">
          <input v-model="customFrom" type="date" style="width: auto" />
          <span class="muted">—</span>
          <input v-model="customTo" type="date" style="width: auto" />
        </template>
        <button class="btn" @click="refresh()">Yenile</button>
        <button class="btn btn-primary" :disabled="!data || exporting" @click="exportExcel">
          {{ exporting ? 'Hazırlanıyor...' : 'Excel olarak indir' }}
        </button>
      </div>
    </div>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending || !data" class="muted">Yükleniyor...</div>

    <div v-else style="display: flex; flex-direction: column; gap: 24px">
      <div class="stat-grid">
        <div class="stat-card">
          <div class="value">{{ data.redOrani.toplamDenetim }}</div>
          <div class="label">Toplam denetim</div>
        </div>
        <div class="stat-card">
          <div class="value">{{ data.redOrani.onay }}</div>
          <div class="label">Onaylanan</div>
        </div>
        <div class="stat-card">
          <div class="value">{{ data.redOrani.red }}</div>
          <div class="label">Reddedilen</div>
        </div>
        <div class="stat-card">
          <div class="value">{{ fmtOran(data.redOrani.oran) }}</div>
          <div class="label">Genel red oranı</div>
        </div>
      </div>

      <div>
        <h2 style="font-size: 16px; margin: 0 0 10px">Alt Yüklenici Personel Performansı</h2>
        <div class="card" style="padding: 0">
          <table>
            <thead>
              <tr>
                <th>Personel</th>
                <th>Atanan İş</th>
                <th>Onaylanan</th>
                <th>Reddedilen</th>
                <th>Ort. Müdahale</th>
                <th>Ort. Çözüm</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in data.personelPerformans" :key="p.userId">
                <td>{{ p.ad }}</td>
                <td>{{ p.atananSayisi }}</td>
                <td>{{ p.onaylananSayisi }}</td>
                <td>{{ p.reddedilenSayisi }}</td>
                <td>{{ fmtSaat(p.ortMudahaleSaat) }}</td>
                <td>{{ fmtSaat(p.ortCozumSaat) }}</td>
              </tr>
              <tr v-if="!data.personelPerformans.length">
                <td colspan="6" class="muted">Kayıt yok</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div>
        <h2 style="font-size: 16px; margin: 0 0 10px">Personel Bazlı Red Oranı</h2>
        <div class="card" style="padding: 0">
          <table>
            <thead>
              <tr>
                <th>Personel</th>
                <th>Toplam Denetim</th>
                <th>Red</th>
                <th>Red Oranı</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="u in data.redOrani.byUser" :key="u.userId">
                <td>{{ u.ad }}</td>
                <td>{{ u.toplamDenetim }}</td>
                <td>{{ u.red }}</td>
                <td>{{ fmtOran(u.oran) }}</td>
              </tr>
              <tr v-if="!data.redOrani.byUser.length">
                <td colspan="4" class="muted">Kayıt yok</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div>
        <h2 style="font-size: 16px; margin: 0 0 10px">Malzeme Tüketimi</h2>
        <div class="card" style="padding: 0">
          <table>
            <thead>
              <tr>
                <th>Malzeme</th>
                <th>Birim</th>
                <th>Toplam Miktar</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in data.malzemeTuketimi" :key="m.materialId">
                <td>{{ m.ad }}</td>
                <td>{{ m.birim ?? '—' }}</td>
                <td>{{ m.toplamMiktar.toFixed(2) }}</td>
              </tr>
              <tr v-if="!data.malzemeTuketimi.length">
                <td colspan="3" class="muted">Kayıt yok</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
