import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { teams } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const id = Number(getRouterParam(event, 'id'))

  const [team] = await useDb().select().from(teams).where(eq(teams.id, id)).limit(1)
  if (!team) {
    throw createError({ statusCode: 404, statusMessage: 'Ekip bulunamadı' })
  }
  return team
})
