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

function fmtDate(v: string) {
  return new Date(v).toLocaleDateString('tr-TR')
}

const MAX_BAR_PX = 120

function redOranBarHeight(oran: number | null) {
  if (oran === null) return 2
  return Math.max(oran * MAX_BAR_PX, 2)
}

const maxSureSaat = computed(() => {
  if (!data.value) return 1
  const values = data.value.sureTrend.flatMap((t) => [t.ortMudahaleSaat, t.ortCozumSaat]).filter((v): v is number => v !== null)
  return values.length ? Math.max(...values) : 1
})

function sureBarHeight(saat: number | null) {
  if (saat === null || maxSureSaat.value <= 0) return 2
  return Math.max((saat / maxSureSaat.value) * MAX_BAR_PX, 2)
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
        headers: ['Personel', 'Atanan İş', 'Çözdüğü İş', 'Onaylanan', 'Reddedilen', 'Ort. Müdahale (sa)', 'Ort. Çözüm (sa)'],
        rows: data.value.personelPerformans.map((p) => [
          p.ad,
          p.atananSayisi,
          p.cozdugSayisi,
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
      {
        name: 'Red Oranı Trendi',
        headers: ['Ay', 'Toplam Denetim', 'Red', 'Red Oranı (%)'],
        rows: data.value.redOraniTrend.map((t) => [t.period, t.toplamDenetim, t.red, t.oran !== null ? Number((t.oran * 100).toFixed(1)) : null]),
      },
      {
        name: 'Süre Trendi',
        headers: ['Ay', 'Ort. Müdahale (sa)', 'Ort. Çözüm (sa)'],
        rows: data.value.sureTrend.map((t) => [
          t.period,
          t.ortMudahaleSaat !== null ? Number(t.ortMudahaleSaat.toFixed(2)) : null,
          t.ortCozumSaat !== null ? Number(t.ortCozumSaat.toFixed(2)) : null,
        ]),
      },
      {
        name: 'Tekrarlayan Arızalar',
        headers: ['Saha', 'Ünite', 'Son 90 Günde Arıza', 'Son Arıza'],
        rows: data.value.tekrarlayanArizalar.map((t) => [t.siteAd, t.ekipmanLabel, t.sonDoksanGunArizaSayisi, fmtDate(t.sonArizaTarihi)]),
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
                <th>Çözdüğü İş</th>
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
                <td>{{ p.cozdugSayisi }}</td>
                <td>{{ p.onaylananSayisi }}</td>
                <td>{{ p.reddedilenSayisi }}</td>
                <td>{{ fmtSaat(p.ortMudahaleSaat) }}</td>
                <td>{{ fmtSaat(p.ortCozumSaat) }}</td>
              </tr>
              <tr v-if="!data.personelPerformans.length">
                <td colspan="7" class="muted">Kayıt yok</td>
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
        <h2 style="font-size: 16px; margin: 0 0 10px">Red Oranı Trendi (Son 6 Ay)</h2>
        <div class="muted" style="font-size: 12px; margin-bottom: 8px">Dönem filtresinden bağımsız, her zaman son 6 ayı gösterir.</div>
        <div class="card">
          <div v-if="!data.redOraniTrend.length" class="muted">Yeterli veri yok.</div>
          <div v-else style="display: flex; align-items: flex-end; gap: 12px; height: 170px">
            <div v-for="t in data.redOraniTrend" :key="t.period" style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end">
              <div style="font-size: 11px; margin-bottom: 4px">{{ fmtOran(t.oran) }}</div>
              <div
                :style="{
                  width: '60%',
                  height: `${redOranBarHeight(t.oran)}px`,
                  background: (t.oran ?? 0) > 0.3 ? '#dc2626' : '#f59e0b',
                  borderRadius: '4px 4px 0 0',
                }"
              />
              <div class="muted" style="font-size: 11px; margin-top: 4px">{{ t.period }}</div>
            </div>
          </div>
        </div>
      </div>

      <div>
        <h2 style="font-size: 16px; margin: 0 0 10px">Müdahale / Çözüm Süresi Trendi (Son 6 Ay)</h2>
        <div class="card">
          <div v-if="!data.sureTrend.length" class="muted">Yeterli veri yok.</div>
          <template v-else>
            <div style="display: flex; gap: 16px; font-size: 12px; margin-bottom: 8px">
              <div style="display: flex; align-items: center; gap: 4px"><span style="width: 10px; height: 10px; background: #2563eb; border-radius: 2px; display: inline-block" /> Ort. Müdahale</div>
              <div style="display: flex; align-items: center; gap: 4px"><span style="width: 10px; height: 10px; background: #16a34a; border-radius: 2px; display: inline-block" /> Ort. Çözüm</div>
            </div>
            <div style="display: flex; align-items: flex-end; gap: 12px; height: 170px">
              <div v-for="t in data.sureTrend" :key="t.period" style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end">
                <div style="display: flex; align-items: flex-end; gap: 4px">
                  <div :style="{ width: '14px', height: `${sureBarHeight(t.ortMudahaleSaat)}px`, background: '#2563eb', borderRadius: '3px 3px 0 0' }" :title="fmtSaat(t.ortMudahaleSaat)" />
                  <div :style="{ width: '14px', height: `${sureBarHeight(t.ortCozumSaat)}px`, background: '#16a34a', borderRadius: '3px 3px 0 0' }" :title="fmtSaat(t.ortCozumSaat)" />
                </div>
                <div class="muted" style="font-size: 11px; margin-top: 4px">{{ t.period }}</div>
              </div>
            </div>
          </template>
        </div>
      </div>

      <div>
        <h2 style="font-size: 16px; margin: 0 0 10px">Tekrarlayan Arızalar</h2>
        <div class="muted" style="font-size: 12px; margin-bottom: 8px">Son 90 günde aynı ünitede 2+ arıza bildirimi — muhtemel kalıcı sorun işareti.</div>
        <div class="card" style="padding: 0">
          <table>
            <thead>
              <tr>
                <th>Saha</th>
                <th>Ünite</th>
                <th>Son 90 Günde Arıza</th>
                <th>Son Arıza</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="t in data.tekrarlayanArizalar" :key="t.equipmentId">
                <td>{{ t.siteAd }}</td>
                <td>{{ t.ekipmanLabel }}</td>
                <td><span class="badge badge-reddedildi">{{ t.sonDoksanGunArizaSayisi }}</span></td>
                <td>{{ fmtDate(t.sonArizaTarihi) }}</td>
                <td><NuxtLink class="btn" :to="`/equipment/${t.equipmentId}`">Künyeyi Gör</NuxtLink></td>
              </tr>
              <tr v-if="!data.tekrarlayanArizalar.length">
                <td colspan="5" class="muted">Tekrarlayan arıza yok.</td>
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
