import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireAuth } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { workOrders, workOrderPhotos } from '../../../database/schema'

const bodySchema = z.object({
  url: z.string().min(1),
  gpsLat: z.number(),
  gpsLng: z.number(),
  cekimZamani: z.string().datetime(),
  boyutKb: z.number().int().optional(),
})

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const db = useDb()
  const [workOrder] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  if (!workOrder) {
    throw createError({ statusCode: 404, statusMessage: 'İş emri bulunamadı' })
  }
  if (workOrder.atananUserId !== Number(payload.sub)) {
    throw createError({ statusCode: 403, statusMessage: 'Bu iş emri size atanmamış' })
  }
  if (!['bekliyor', 'devam_edecek'].includes(workOrder.durum)) {
    throw createError({ statusCode: 409, statusMessage: 'Bu iş emrine artık fotoğraf eklenemez' })
  }

  const [result] = await db.insert(workOrderPhotos).values({
    workOrderId: id,
    url: body.url,
    gpsLat: String(body.gpsLat),
    gpsLng: String(body.gpsLng),
    cekimZamani: new Date(body.cekimZamani),
    yukleyenUserId: Number(payload.sub),
    boyutKb: body.boyutKb,
  })

  const [created] = await db.select().from(workOrderPhotos).where(eq(workOrderPhotos.id, result.insertId)).limit(1)
  setResponseStatus(event, 201)
  return created
})
