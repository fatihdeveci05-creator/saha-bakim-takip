import { desc, eq, inArray } from 'drizzle-orm'
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

  // Atanan ve çözen personelin adı — "kime atanmış"/"kim çözdü" her yerde
  // görünür olsun diye (denetim kuyruğu, raporlar, detay ekranı).
  let atananAd: string | null = null
  let resolvedByAd: string | null = null
  const idsToLookup = [workOrder.atananUserId, workOrder.resolvedByUserId].filter((v): v is number => v != null)
  if (idsToLookup.length) {
    const rows = await db
      .select({ id: users.id, ad: users.ad })
      .from(users)
      .where(inArray(users.id, idsToLookup))
    const byId = new Map(rows.map((r) => [r.id, r.ad]))
    atananAd = workOrder.atananUserId ? (byId.get(workOrder.atananUserId) ?? null) : null
    resolvedByAd = workOrder.resolvedByUserId ? (byId.get(workOrder.resolvedByUserId) ?? null) : null
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

  return { ...workOrder, atananAd, resolvedByAd, photos, reviews, timeline, materials: usedMaterials }
})
