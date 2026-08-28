import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { workOrders, workOrderTimeline, users } from '../../../database/schema'
import { notifyUser } from '../../../utils/notify'

const bodySchema = z.object({
  atananUserId: z.number().int(),
})

// Personel seçmeden oluşturulan (veya değiştirilmek istenen) bir iş emrine
// sonradan atama yapmak için. Sadece "bekliyor" durumundayken (henüz kimse
// müdahaleye başlamamışken) mümkün.
export default defineEventHandler(async (event) => {
  const payload = await requireRole(event, ['yonetici', 'sorumlu'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const db = useDb()
  const [workOrder] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  if (!workOrder) {
    throw createError({ statusCode: 404, statusMessage: 'İş emri bulunamadı' })
  }
  if (workOrder.durum !== 'bekliyor') {
    throw createError({ statusCode: 409, statusMessage: 'Sadece bekleyen iş emirlerine atama yapılabilir' })
  }

  const [assignee] = await db
    .select({ id: users.id, taraf: users.taraf, aktif: users.aktif })
    .from(users)
    .where(eq(users.id, body.atananUserId))
    .limit(1)
  if (!assignee || assignee.taraf !== 'alt_yuklenici' || !assignee.aktif) {
    throw createError({ statusCode: 400, statusMessage: 'Atanan kullanıcı geçersiz (aktif alt yüklenici personeli olmalı)' })
  }

  await db.update(workOrders).set({ atananUserId: body.atananUserId }).where(eq(workOrders.id, id))
  await db.insert(workOrderTimeline).values({
    workOrderId: id,
    durum: 'bekliyor',
    not: 'Personel atandı',
    createdByUserId: Number(payload.sub),
  })
  await notifyUser(body.atananUserId, 'atama', `Size bir iş atandı: #${id}`, id)

  const [updated] = await db.select().from(workOrders).where(eq(workOrders.id, id)).limit(1)
  return updated
})
