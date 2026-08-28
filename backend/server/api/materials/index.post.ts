import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { materials } from '../../database/schema'

const bodySchema = z.object({
  ad: z.string().min(1),
  birim: z.string().max(50).optional(),
  stokAdedi: z.number().int().nonnegative().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const body = await readValidatedBody(event, bodySchema.parse)

  const [result] = await useDb().insert(materials).values({
    ad: body.ad,
    birim: body.birim,
    stokAdedi: body.stokAdedi ?? 0,
  })

  const [created] = await useDb().select().from(materials).where(eq(materials.id, result.insertId)).limit(1)
  setResponseStatus(event, 201)
  return created
})
