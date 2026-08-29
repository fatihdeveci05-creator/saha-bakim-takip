import { desc, eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import {
  workOrders,
  workOrderPhotos,
  workOrderReviews,
  workOrderTimeline,
  workOrderMaterials,
  materials,
  users,
} from '../../database/schema'
import { assertCanViewWorkOrder } from '../../utils/workOrderAccess'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const id = Number(getRouterParam(event, 'id'))
  const db = useDb()

  const [workOrder] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  if (!workOrder) {
    throw createError({ statusCode: 404, statusMessage: 'İş emri bulunamadı' })
  }
  assertCanViewWorkOrder(payload, workOrder)

  // Atanan personelin adı — listede/detayda "kime atanmış" görünür olsun diye
  // (aksi halde diğer personel "size atanmamış" hatasını neden aldığını göremiyor).
  let atananAd: string | null = null
  if (workOrder.atananUserId) {
    const [assignee] = await db.select({ ad: users.ad }).from(users).where(eq(users.id, workOrder.atananUserId)).limit(1)
    atananAd = assignee?.ad ?? null
  }

  const [photos, reviews, timeline, usedMaterials] = await Promise.all([
    db.select().from(workOrderPhotos).where(eq(workOrderPhotos.workOrderId, id)),
    db
      .select()
      .from(workOrderReviews)
      .where(eq(workOrderReviews.workOrderId, id))
      .orderBy(desc(workOrderReviews.incelenenZaman)),
    db
      .select()
      .from(workOrderTimeline)
      .where(eq(workOrderTimeline.workOrderId, id))
      .orderBy(desc(workOrderTimeline.createdAt)),
    db
      .select({
        materialId: workOrderMaterials.materialId,
        miktar: workOrderMaterials.miktar,
        ad: materials.ad,
        birim: materials.birim,
      })
      .from(workOrderMaterials)
      .innerJoin(materials, eq(materials.id, workOrderMaterials.materialId))
      .where(eq(workOrderMaterials.workOrderId, id)),
  ])

  return { ...workOrder, atananAd, photos, reviews, timeline, materials: usedMaterials }
})
