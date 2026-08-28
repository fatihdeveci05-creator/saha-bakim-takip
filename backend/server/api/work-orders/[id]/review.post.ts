import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { workOrders, workOrderReviews, workOrderTimeline } from '../../../database/schema'
import { notifyUser } from '../../../utils/notify'

const bodySchema = z
  .object({
    sonuc: z.enum(['onay', 'red']),
    gerekce: z.string().min(1).optional(),
  })
  .refine((v) => v.sonuc !== 'red' || !!v.gerekce, {
    message: 'Red için gerekçe zorunludur',
    path: ['gerekce'],
  })

export default defineEventHandler(async (event) => {
  const payload = await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const db = useDb()
  const [workOrder] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  if (!workOrder) {
    throw createError({ statusCode: 404, statusMessage: 'İş emri bulunamadı' })
  }
  if (workOrder.durum !== 'onay_bekliyor') {
    throw createError({ statusCode: 409, statusMessage: 'Bu iş emri onay bekleyen durumda değil' })
  }

  await db.insert(workOrderReviews).values({
    workOrderId: id,
    reviewerUserId: Number(payload.sub),
    sonuc: body.sonuc,
    gerekce: body.gerekce,
  })

  if (body.sonuc === 'onay') {
    await db.update(workOrders).set({ durum: 'onaylandi' }).where(eq(workOrders.id, id))
    await db.insert(workOrderTimeline).values({
      workOrderId: id,
      durum: 'onaylandi',
      createdByUserId: Number(payload.sub),
    })

    if (workOrder.atananUserId) {
      await notifyUser(workOrder.atananUserId, 'onay', `İş emri #${id} onaylandı`, id)
    }

    const [updated] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
    return { workOrder: updated, newWorkOrder: null }
  }

  // Red: orijinal kayıt olduğu gibi kalır (immutable), yeni bir iş emri açılır
  await db.update(workOrders).set({ durum: 'reddedildi' }).where(eq(workOrders.id, id))
  await db.insert(workOrderTimeline).values({
    workOrderId: id,
    durum: 'reddedildi',
    not: body.gerekce,
    createdByUserId: Number(payload.sub),
  })

  const now = new Date()
  const [newResult] = await db.insert(workOrders).values({
    equipmentId: workOrder.equipmentId,
    tip: workOrder.tip,
    atananUserId: workOrder.atananUserId,
    oncelik: workOrder.oncelik,
    aciklama: workOrder.aciklama,
    durum: 'bekliyor',
    parentWorkOrderId: id,
    reportedAt: now,
    reportedAtServer: now,
  })

  await db.insert(workOrderTimeline).values({
    workOrderId: newResult.insertId,
    durum: 'bekliyor',
    not: `Reddedilen #${id} işinin düzeltmesi olarak açıldı`,
    createdByUserId: Number(payload.sub),
  })

  if (workOrder.atananUserId) {
    await notifyUser(workOrder.atananUserId, 'red', `İş emri #${id} reddedildi: ${body.gerekce}`, newResult.insertId)
  }

  const [updated] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  const [created] = await db.select().from(workOrders).where(eq(workOrders.id, newResult.insertId)).limit(1)
  return { workOrder: updated, newWorkOrder: created }
})
