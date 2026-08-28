import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { notifications } from '../../database/schema'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  await useDb().update(notifications).set({ okundu: true }).where(eq(notifications.userId, Number(payload.sub)))
  return { ok: true }
})
