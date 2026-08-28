import { desc, eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { notifications } from '../../database/schema'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)

  return useDb()
    .select()
    .from(notifications)
    .where(eq(notifications.userId, Number(payload.sub)))
    .orderBy(desc(notifications.createdAt))
    .limit(100)
})
