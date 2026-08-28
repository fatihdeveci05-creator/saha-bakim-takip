import { eq } from 'drizzle-orm'
import { requireAuth } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { notifications } from '../../../database/schema'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const id = Number(getRouterParam(event, 'id'))

  const db = useDb()
  const [existing] = await db.select({ userId: notifications.userId }).from(notifications).where(eq(notifications.id, id)).limit(1)
  if (!existing || existing.userId !== Number(payload.sub)) {
    throw createError({ statusCode: 404, statusMessage: 'Bildirim bulunamadı' })
  }

  await db.update(notifications).set({ okundu: true }).where(eq(notifications.id, id))
  return { ok: true }
})
