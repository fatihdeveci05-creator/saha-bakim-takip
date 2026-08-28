import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { teams, ekipTipEnum } from '../../database/schema'

const bodySchema = z.object({
  ad: z.string().min(1),
  tip: z.enum(ekipTipEnum),
  sorumluUserId: z.number().int().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const body = await readValidatedBody(event, bodySchema.parse)

  const [result] = await useDb().insert(teams).values(body)

  const [created] = await useDb().select().from(teams).where(eq(teams.id, result.insertId)).limit(1)
  setResponseStatus(event, 201)
  return created
})
