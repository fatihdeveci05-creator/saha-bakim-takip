import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { notifications } from '../../database/schema'

// Kullanıcının kendi bildirim listesini tamamen temizler.
export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  await useDb().delete(notifications).where(eq(notifications.userId, Number(payload.sub)))
  return { ok: true }
})
