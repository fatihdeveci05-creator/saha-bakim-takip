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

  const [allSites, allEquipment, openWorkOrders, allReportedAt] = await Promise.all([
    db.select().from(sites),
    db.select().from(equipment),
    db
      .select({ equipmentId: workOrders.equipmentId, tip: workOrders.tip })
      .from(workOrders)
      .where(inArray(workOrders.durum, ACIK_DURUMLAR)),
    // Son aktivite (kontrol geçişi veya arıza/bakım bildirimi) — grid'de son
    // kontrol edilen en üstte görünsün diye. Kontrol Ekibi'nin "Sorun Yok"
    // geçişleri (tip='kontrol') ve arıza/bakım bildirimleri hepsi sayılır.
    db.select({ equipmentId: workOrders.equipmentId, reportedAt: workOrders.reportedAt }).from(workOrders),
  ])

  const acikArizaEquipmentIds = new Set(openWorkOrders.filter((w) => w.tip === 'ariza').map((w) => w.equipmentId))
  const acikBakimEquipmentIds = new Set(openWorkOrders.filter((w) => w.tip === 'bakim').map((w) => w.equipmentId))

  const sonAktiviteByEquipmentId = new Map<number, Date>()
  for (const w of allReportedAt) {
    if (!w.reportedAt) continue
    const current = sonAktiviteByEquipmentId.get(w.equipmentId)
    if (!current || w.reportedAt > current) sonAktiviteByEquipmentId.set(w.equipmentId, w.reportedAt)
  }

  function ekipmanRengi(equipmentId: number): Renk {
    if (acikArizaEquipmentIds.has(equipmentId)) return 'kirmizi'
    if (acikBakimEquipmentIds.has(equipmentId)) return 'sari'
    return 'yesil'
  }

  function enKotu(a: Renk, b: Renk): Renk {
    const oncelik: Record<Renk, number> = { kirmizi: 2, sari: 1, yesil: 0 }
    return oncelik[a] >= oncelik[b] ? a : b
  }

  const result = allSites.map((site) => {
    const siteEquipmentIds = allEquipment.filter((e) => e.siteId === site.id).map((e) => e.id)
    const siteEquipment = siteEquipmentIds.map((id) => {
      const e = allEquipment.find((eq2) => eq2.id === id)!
      return { id: e.id, tip: e.tip, marka: e.marka, model: e.model, seriNo: e.seriNo, durum: ekipmanRengi(e.id) }
    })
    const durum = siteEquipment.reduce<Renk>((acc, e) => enKotu(acc, e.durum), 'yesil')
    const sonKontrol = siteEquipmentIds.reduce<Date | null>((acc, id) => {
      const t = sonAktiviteByEquipmentId.get(id)
      if (!t) return acc
      return !acc || t > acc ? t : acc
    }, null)

    return {
      id: site.id,
      ad: site.ad,
      lat: site.lat,
      lng: site.lng,
      durum,
      sonKontrol,
      equipment: siteEquipment,
    }
  })

  // Son aktivitesi (kontrol geçişi/arıza bildirimi) olan sahalar en üstte, en
  // yenisi ilk sırada; hiç aktivitesi olmayan sahalar en altta.
  return result.sort((a, b) => {
    if (!a.sonKontrol && !b.sonKontrol) return 0
    if (!a.sonKontrol) return 1
    if (!b.sonKontrol) return -1
    return b.sonKontrol.getTime() - a.sonKontrol.getTime()
  })
})
