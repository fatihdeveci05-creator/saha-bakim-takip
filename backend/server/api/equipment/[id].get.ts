import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const id = Number(getRouterParam(event, 'id'))

  const [item] = await useDb().select().from(equipment).where(eq(equipment.id, id)).limit(1)
  if (!item) {
    throw createError({ statusCode: 404, statusMessage: 'Ekipman bulunamadı' })
  }
  return item
})
