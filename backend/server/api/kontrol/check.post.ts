import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment, sites, workOrders } from '../../database/schema'
import { distanceMeters, KONTROL_YARICAP_METRE } from '../../utils/geo'

const bodySchema = z.object({
  equipmentId: z.number().int(),
  lat: z.number(),
  lng: z.number(),
})

// Kontrol Ekibi'nin "Sorun Yok" hızlı onayı. Foto/checklist yok — kanıt GPS+zaman.
// Konum sunucu tarafında da doğrulanır (100m yarıçap dışından onay verilemez).
// Sonuç direkt "onaylandı" ile kapanır, İşveren denetimine düşmez (PLAN.md böl. 2).
export default defineEventHandler(async (event) => {
  const payload = await requireRole(event, ['kontrol_ekibi'])
  const body = await readValidatedBody(event, bodySchema.parse)

  const db = useDb()
  const [row] = await db
    .select({
      equipmentId: equipment.id,
      aktif: equipment.aktif,
      siteLat: sites.lat,
      siteLng: sites.lng,
    })
    .from(equipment)
    .innerJoin(sites, eq(sites.id, equipment.siteId))
    .where(eq(equipment.id, body.equipmentId))
    .limit(1)

  if (!row) {
    throw createError({ statusCode: 404, statusMessage: 'Ekipman bulunamadı' })
  }
  if (!row.aktif) {
    throw createError({ statusCode: 409, statusMessage: 'Bu ekipman aktif değil' })
  }
  if (row.siteLat === null || row.siteLng === null) {
    throw createError({ statusCode: 409, statusMessage: 'Bu ekipmanın saha konumu tanımlı değil' })
  }

  const dist = distanceMeters(body.lat, body.lng, Number(row.siteLat), Number(row.siteLng))
  if (dist > KONTROL_YARICAP_METRE) {
    throw createError({
      statusCode: 403,
      statusMessage: `Bu ekipmana ${KONTROL_YARICAP_METRE}m yarıçap dışındasınız (${Math.round(dist)}m)`,
    })
  }

  const now = new Date()
  const [result] = await db.insert(workOrders).values({
    equipmentId: body.equipmentId,
    tip: 'kontrol',
    atananUserId: Number(payload.sub),
    durum: 'onaylandi',
    aciklama: 'Kontrol Ekibi denetimi — sorun yok',
    reportedAt: now,
    reportedAtServer: now,
    responseStartedAt: now,
    resolvedAt: now,
    resolvedByUserId: Number(payload.sub),
    checkGpsLat: String(body.lat),
    checkGpsLng: String(body.lng),
  })

  const [created] = await db.select().from(workOrders).where(eq(workOrders.id, result.insertId)).limit(1)
  return created
})
