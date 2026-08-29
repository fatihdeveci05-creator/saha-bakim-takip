import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment, sites } from '../../database/schema'
import { distanceMeters, KONTROL_YARICAP_METRE } from '../../utils/geo'

const querySchema = z.object({
  lat: z.coerce.number(),
  lng: z.coerce.number(),
})

// Kontrol Ekibi'nin ana ekranı: mevcut konuma en yakın, aktif ekipmanı olan
// sahayı ve o sahadaki aktif ekipman listesini döner.
export default defineEventHandler(async (event) => {
  await requireRole(event, ['kontrol_ekibi'])
  const { lat, lng } = await getValidatedQuery(event, querySchema.parse)

  const rows = await useDb()
    .select({
      equipmentId: equipment.id,
      equipmentTip: equipment.tip,
      marka: equipment.marka,
      model: equipment.model,
      seriNo: equipment.seriNo,
      siteId: sites.id,
      siteAd: sites.ad,
      siteLat: sites.lat,
      siteLng: sites.lng,
    })
    .from(equipment)
    .innerJoin(sites, eq(sites.id, equipment.siteId))
    .where(eq(equipment.aktif, true))

  if (!rows.length) {
    return { site: null, equipment: [], distanceMeters: null, icinde: false }
  }

  const bySite = new Map<number, typeof rows>()
  for (const r of rows) {
    if (r.siteLat === null || r.siteLng === null) continue
    const list = bySite.get(r.siteId) ?? []
    list.push(r)
    bySite.set(r.siteId, list)
  }

  let en: { siteId: number; siteAd: string; dist: number; items: typeof rows } | null = null
  for (const [siteId, items] of bySite) {
    const first = items[0]
    const dist = distanceMeters(lat, lng, Number(first.siteLat), Number(first.siteLng))
    if (!en || dist < en.dist) {
      en = { siteId, siteAd: first.siteAd, dist, items }
    }
  }

  if (!en) {
    return { site: null, equipment: [], distanceMeters: null, icinde: false }
  }

  return {
    site: { id: en.siteId, ad: en.siteAd },
    distanceMeters: Math.round(en.dist),
    icinde: en.dist <= KONTROL_YARICAP_METRE,
    equipment: en.items.map((i) => ({
      id: i.equipmentId,
      tip: i.equipmentTip,
      marka: i.marka,
      model: i.model,
      seriNo: i.seriNo,
    })),
  }
})
