import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { materials } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireAuth(event)
  return useDb().select().from(materials)
})
