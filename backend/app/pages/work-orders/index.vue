<script setup lang="ts">
import type { WorkOrder, Equipment, Site, Durum, AppUser } from '~/types'
import { DURUM_LABELS } from '~/types'
import { PERIOD_LABELS } from '~/utils/dateRange'

const { apiFetch } = useApi()
const auth = useAuth()
const route = useRoute()
const router = useRouter()

// İş Emirleri listesi süresiz uzamasın diye varsayılan olarak "Bugün" — istenirse
// filtreden Bu Hafta/Bu Ay/Tüm Zamanlar/Özel Aralık seçilebilir.
const { period: periodFilter, customFrom, customTo, queryString } = useDateFilter('bugun')
const durumFilter = ref<Durum | ''>((route.query.durum as Durum) || '')

watch(durumFilter, () => {
  const query = { ...route.query }
  if (durumFilter.value) query.durum = durumFilter.value
  else delete query.durum
  router.replace({ query })
})

const { data: items, pending, error, refresh } = await useAsyncData(
  'work-orders-list',
  () => {
    const params = new URLSearchParams(queryString.value)
    if (durumFilter.value) params.set('durum', durumFilter.value)
    const qs = params.toString()
    return apiFetch<WorkOrder[]>(`/api/work-orders${qs ? `?${qs}` : ''}`)
  },
  { watch: [durumFilter, queryString] },
)

const { data: equipmentList } = await useAsyncData('equipment-lookup', () => apiFetch<Equipment[]>('/api/equipment'))
const { data: siteList } = await useAsyncData('sites-lookup', () => apiFetch<Site[]>('/api/sites'))
const { data: userList } = await useAsyncData('users-lookup', () => apiFetch<AppUser[]>('/api/users'))

const siteNameById = computed(() => new Map((siteList.value ?? []).map((s) => [s.id, s.ad])))
const equipmentById = computed(() => new Map((equipmentList.value ?? []).map((e) => [e.id, e])))
const altYuklenicilar = computed(() => (userList.value ?? []).filter((u) => u.taraf === 'alt_yuklenici' && u.aktif))

function equipmentLabel(equipmentId: number) {
  const eq = equipmentById.value.get(equipmentId)
  if (!eq) return `#${equipmentId}`
  const siteName = siteNameById.value.get(eq.siteId) ?? `Saha #${eq.siteId}`
  return `${siteName} — ${eq.marka ?? ''} ${eq.model ?? ''}`.trim()
}

const tipLabels: Record<string, string> = { bakim: 'Bakım', ariza: 'Arıza', kontrol: 'Kontrol' }
const tipOrder = ['ariza', 'bakim', 'kontrol'] as const

// Tipleri (Arıza/Bakım/Kontrol) karışık tek listede değil, ayrı gridler
// halinde göstermek için grupla — birbirine karışmasınlar diye.
const itemsByTip = computed(() => {
  const groups = new Map<string, WorkOrder[]>(tipOrder.map((t) => [t, []]))
  for (const wo of items.value ?? []) {
    groups.get(wo.tip)?.push(wo)
  }
  return groups
})

function fmt(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleString('tr-TR')
}

// Sadece yönetici (backend'in izin verdiği rol) iş emri oluşturup atayabilir.
const canCreate = computed(() => auth.user.value?.rol === 'yonetici')

const showForm = ref(false)
const form = reactive({ equipmentId: '', tip: 'bakim', atananUserId: '', oncelik: '', aciklama: '' })
const formError = ref('')
const saving = ref(false)

async function submit() {
  formError.value = ''
  saving.value = true
  try {
    await apiFetch('/api/work-orders', {
      method: 'POST',
      body: {
        equipmentId: Number(form.equipmentId),
        tip: form.tip,
        atananUserId: form.atananUserId ? Number(form.atananUserId) : undefined,
        oncelik: form.oncelik || undefined,
        aciklama: form.aciklama || undefined,
      },
    })
    form.equipmentId = ''
    form.atananUserId = ''
    form.oncelik = ''
    form.aciklama = ''
    showForm.value = false
    await refresh()
  } catch (err) {
    formError.value = (err as { data?: { statusMessage?: string } })?.data?.statusMessage || 'Kaydedilemedi'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-header">
      <h1>İş Emirleri</h1>
      <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap">
        <select v-model="periodFilter" style="width: auto">
          <option v-for="(label, key) in PERIOD_LABELS" :key="key" :value="key">{{ label }}</option>
        </select>
        <template v-if="periodFilter === 'ozel'">
          <input v-model="customFrom" type="date" style="width: auto" />
          <span class="muted">—</span>
          <input v-model="customTo" type="date" style="width: auto" />
        </template>
        <select v-model="durumFilter" style="width: auto">
          <option value="">Tüm durumlar</option>
          <option v-for="(label, key) in DURUM_LABELS" :key="key" :value="key">{{ label }}</option>
        </select>
        <button v-if="canCreate" class="btn btn-primary" @click="showForm = !showForm">
          {{ showForm ? 'Vazgeç' : '+ Yeni İş Emri' }}
        </button>
      </div>
    </div>

    <form v-if="showForm" class="card" style="margin-bottom: 16px" @submit.prevent="submit">
      <div v-if="formError" class="error-box">{{ formError }}</div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">
        <div class="field">
          <label>Ekipman</label>
          <select v-model="form.equipmentId" required>
            <option value="" disabled>Seçin</option>
            <option v-for="e in equipmentList" :key="e.id" :value="e.id">{{ equipmentLabel(e.id) }}</option>
          </select>
        </div>
        <div class="field">
          <label>Tip</label>
          <select v-model="form.tip">
            <option value="bakim">Bakım</option>
            <option value="kontrol">Kontrol</option>
            <option value="ariza">Arıza</option>
          </select>
        </div>
      </div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">
        <div class="field">
          <label>Atanacak Personel (isteğe bağlı)</label>
          <select v-model="form.atananUserId">
            <option value="">Şimdilik atama</option>
            <option v-for="u in altYuklenicilar" :key="u.id" :value="u.id">{{ u.ad }} ({{ u.rol }})</option>
          </select>
        </div>
        <div class="field">
          <label>Öncelik</label>
          <select v-model="form.oncelik">
            <option value="">—</option>
            <option value="dusuk">Düşük</option>
            <option value="orta">Orta</option>
            <option value="yuksek">Yüksek</option>
          </select>
        </div>
      </div>
      <div class="field">
        <label>Açıklama</label>
        <textarea v-model="form.aciklama" rows="2"></textarea>
      </div>
      <button class="btn btn-primary" type="submit" :disabled="saving">Kaydet</button>
    </form>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Kayıt yok.</div>

    <div v-else style="display: flex; flex-direction: column; gap: 20px">
      <div v-for="tip in tipOrder" :key="tip">
        <h2 style="font-size: 16px; margin: 0 0 8px">
          {{ tipLabels[tip] }} <span class="muted" style="font-weight: normal">({{ itemsByTip.get(tip)?.length ?? 0 }})</span>
        </h2>
        <div v-if="!itemsByTip.get(tip)?.length" class="card muted" style="padding: 14px">Kayıt yok.</div>
        <div v-else class="card" style="padding: 0">
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Ekipman / Saha</th>
                <th>Durum</th>
                <th>Bildirim</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="wo in itemsByTip.get(tip)" :key="wo.id">
                <td>{{ wo.id }}</td>
                <td>{{ equipmentLabel(wo.equipmentId) }}</td>
                <td><span class="badge" :class="`badge-${wo.durum}`">{{ DURUM_LABELS[wo.durum] }}</span></td>
                <td>{{ fmt(wo.reportedAt) }}</td>
                <td>
                  <NuxtLink class="btn" :to="`/work-orders/${wo.id}`">Detay</NuxtLink>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
