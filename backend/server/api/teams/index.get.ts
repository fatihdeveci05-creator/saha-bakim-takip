import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { teams } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireAuth(event)
  return useDb().select().from(teams)
})
