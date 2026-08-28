import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { teams, ekipTipEnum } from '../../database/schema'

const bodySchema = z.object({
  ad: z.string().min(1).optional(),
  tip: z.enum(ekipTipEnum).optional(),
  sorumluUserId: z.number().int().nullable().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const [existing] = await useDb().select({ id: teams.id }).from(teams).where(eq(teams.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Ekip bulunamadı' })
  }

  await useDb().update(teams).set(body).where(eq(teams.id, id))

  const [updated] = await useDb().select().from(teams).where(eq(teams.id, id)).limit(1)
  return updated
})
