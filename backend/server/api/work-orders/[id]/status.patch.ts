import { eq, count } from 'drizzle-orm'
import { z } from 'zod'
import { requireAuth } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { workOrders, workOrderPhotos, workOrderTimeline } from '../../../database/schema'
import { canClaimUnassignedWorkOrder } from '../../../utils/workOrderAccess'

const bodySchema = z.object({
  durum: z.enum(['devam_edecek', 'tamamlandi', 'na']),
  not: z.string().max(500).optional(),
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
  // Atanan personel kendi işini tamamlar; Yüklenici (sorumlu) herhangi bir
  // saha personelinin işini de tamamlayabilir (yetki matrisi, PLAN.md böl. 2).
  // Atanmamış (atanan_user_id = null) bir iş, tipine uygun rol tarafından
  // (örn. herhangi bir Arıza Ekibi üyesi) işlem görebilir — ama kimseye
  // "kilitlenmez", atanan_user_id null kalır (bilinçli atama sadece
  // /assign endpoint'i veya Yüklenici/İşveren ile yapılır). Kim çözdüğü
  // yine de resolvedByUserId ile ayrıca kayıt altına alınır.
  const isAssignee = workOrder.atananUserId === Number(payload.sub)
  const isSorumlu = payload.rol === 'sorumlu'
  const isOpenForRole = workOrder.atananUserId === null && canClaimUnassignedWorkOrder(payload, workOrder.tip)
  if (!isAssignee && !isSorumlu && !isOpenForRole) {
    throw createError({ statusCode: 403, statusMessage: 'Bu iş emri size atanmamış' })
  }
  if (!['bekliyor', 'devam_edecek'].includes(workOrder.durum)) {
    throw createError({ statusCode: 409, statusMessage: 'Bu iş emrinin durumu artık değiştirilemez' })
  }

  const now = new Date()
  let finalDurum: (typeof workOrders.$inferSelect)['durum'] = body.durum
  const updates: Partial<typeof workOrders.$inferInsert> = {}

  if (body.durum === 'tamamlandi') {
    const photoCountRows = await db
      .select({ value: count() })
      .from(workOrderPhotos)
      .where(eq(workOrderPhotos.workOrderId, id))
    if ((photoCountRows[0]?.value ?? 0) < 3) {
      throw createError({ statusCode: 400, statusMessage: 'Tamamlandı için en az 3 fotoğraf eklenmiş olmalı' })
    }
    finalDurum = 'onay_bekliyor'
    updates.resolvedAt = now
    updates.resolvedByUserId = Number(payload.sub)
  } else if (body.durum === 'devam_edecek') {
    if (!workOrder.responseStartedAt) {
      updates.responseStartedAt = now
    }
  }

  updates.durum = finalDurum
  await db.update(workOrders).set(updates).where(eq(workOrders.id, id))

  await db.insert(workOrderTimeline).values({
    workOrderId: id,
    durum: finalDurum,
    not: body.not,
    createdByUserId: Number(payload.sub),
  })

  const [updated] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  return updated
})
