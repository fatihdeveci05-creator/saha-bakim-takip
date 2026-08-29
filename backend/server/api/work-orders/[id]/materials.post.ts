import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireAuth } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { workOrders, workOrderMaterials, materials } from '../../../database/schema'

const bodySchema = z.object({
  materialId: z.number().int(),
  miktar: z.number().positive(),
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
  if (workOrder.atananUserId !== Number(payload.sub) && payload.rol !== 'sorumlu') {
    throw createError({ statusCode: 403, statusMessage: 'Bu iş emri size atanmamış' })
  }
  if (!['bekliyor', 'devam_edecek'].includes(workOrder.durum)) {
    throw createError({ statusCode: 409, statusMessage: 'Bu iş emrine artık malzeme eklenemez' })
  }

  const [material] = await db.select({ id: materials.id }).from(materials).where(eq(materials.id, body.materialId)).limit(1)
  if (!material) {
    throw createError({ statusCode: 400, statusMessage: 'Malzeme bulunamadı' })
  }

  await db
    .insert(workOrderMaterials)
    .values({ workOrderId: id, materialId: body.materialId, miktar: String(body.miktar) })
    .onDuplicateKeyUpdate({ set: { miktar: String(body.miktar) } })

  return db
    .select()
    .from(workOrderMaterials)
    .where(eq(workOrderMaterials.workOrderId, id))
})
