import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const query = getQuery(event)
  const siteId = query.siteId ? Number(query.siteId) : undefined

  const db = useDb()
  if (siteId) {
    return db.select().from(equipment).where(eq(equipment.siteId, siteId))
  }
  return db.select().from(equipment)
})
