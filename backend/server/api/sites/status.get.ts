import { eq, inArray } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { sites, equipment, workOrders } from '../../database/schema'

// Açık (henüz kapanmamış) iş emri durumları — bunlardan biri varsa o ekipmanda
// "devam eden bir şey" var demektir.
const ACIK_DURUMLAR = ['bekliyor', 'devam_edecek', 'onay_bekliyor'] as const

type Renk = 'kirmizi' | 'sari' | 'yesil'

// Saha/ekipman durum özeti — Canlı Harita'daki saha noktaları ve "Sahalar" grid
// sayfası için. Kırmızı: açık arıza var. Sarı: açık arıza yok ama açık bakım var.
// Yeşil: ikisi de yok. Saha, kendi ekipmanlarının en kötü rengini alır
// (kırmızı > sarı > yeşil).
export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici', 'sorumlu'])
  const db = useDb()

  const [allSites, allEquipment, openWorkOrders] = await Promise.all([
    db.select().from(sites),
    db.select().from(equipment),
    db
      .select({ equipmentId: workOrders.equipmentId, tip: workOrders.tip })
      .from(workOrders)
      .where(inArray(workOrders.durum, ACIK_DURUMLAR)),
  ])

  const acikArizaEquipmentIds = new Set(openWorkOrders.filter((w) => w.tip === 'ariza').map((w) => w.equipmentId))
  const acikBakimEquipmentIds = new Set(openWorkOrders.filter((w) => w.tip === 'bakim').map((w) => w.equipmentId))

  function ekipmanRengi(equipmentId: number): Renk {
    if (acikArizaEquipmentIds.has(equipmentId)) return 'kirmizi'
    if (acikBakimEquipmentIds.has(equipmentId)) return 'sari'
    return 'yesil'
  }

  function enKotu(a: Renk, b: Renk): Renk {
    const oncelik: Record<Renk, number> = { kirmizi: 2, sari: 1, yesil: 0 }
    return oncelik[a] >= oncelik[b] ? a : b
  }

  return allSites.map((site) => {
    const siteEquipment = allEquipment
      .filter((e) => e.siteId === site.id)
      .map((e) => ({
        id: e.id,
        tip: e.tip,
        marka: e.marka,
        model: e.model,
        seriNo: e.seriNo,
        durum: ekipmanRengi(e.id),
      }))
    const durum = siteEquipment.reduce<Renk>((acc, e) => enKotu(acc, e.durum), 'yesil')

    return {
      id: site.id,
      ad: site.ad,
      lat: site.lat,
      lng: site.lng,
      durum,
      equipment: siteEquipment,
    }
  })
})
