<script setup lang="ts">
import type { WorkOrder } from '~/types'

const { apiFetch } = useApi()

const { data: items, pending, error, refresh } = await useAsyncData('onay-bekleyen', () =>
  apiFetch<WorkOrder[]>('/api/work-orders?durum=onay_bekliyor'),
)

const tipLabels: Record<string, string> = { bakim: 'Bakım', ariza: 'Arıza', kontrol: 'Kontrol' }

function fmt(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleString('tr-TR')
}

onActivated(() => refresh())
</script>

<template>
  <div>
    <div class="page-header">
      <h1>Denetim Kuyruğu</h1>
      <button class="btn" @click="refresh()">Yenile</button>
    </div>

    <div v-if="error" class="error-box">Veriler yüklenemedi</div>
    <div v-else-if="pending" class="muted">Yükleniyor...</div>
    <div v-else-if="!items?.length" class="card muted">Onay bekleyen iş emri yok.</div>

    <div v-else class="card" style="padding: 0">
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Ekipman</th>
            <th>Tip</th>
            <th>Çözen</th>
            <th>Çözüldü</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="wo in items" :key="wo.id">
            <td>{{ wo.id }}</td>
            <td>#{{ wo.equipmentId }}</td>
            <td>{{ tipLabels[wo.tip] }}</td>
            <td>{{ wo.resolvedByAd ?? (wo.resolvedByUserId ? `#${wo.resolvedByUserId}` : '—') }}</td>
            <td>{{ fmt(wo.resolvedAt) }}</td>
            <td>
              <NuxtLink class="btn btn-primary" :to="`/work-orders/${wo.id}`">İncele</NuxtLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
