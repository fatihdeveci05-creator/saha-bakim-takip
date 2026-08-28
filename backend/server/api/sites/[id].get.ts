import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { sites } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const id = Number(getRouterParam(event, 'id'))

  const [site] = await useDb().select().from(sites).where(eq(sites.id, id)).limit(1)
  if (!site) {
    throw createError({ statusCode: 404, statusMessage: 'Saha bulunamadı' })
  }
  return site
})
