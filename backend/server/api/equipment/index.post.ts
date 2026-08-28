import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment, ekipmanTipEnum } from '../../database/schema'

const bodySchema = z.object({
  siteId: z.number().int(),
  tip: z.enum(ekipmanTipEnum),
  marka: z.string().optional(),
  model: z.string().optional(),
  seriNo: z.string().optional(),
  kurulumTarihi: z.string().datetime().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const body = await readValidatedBody(event, bodySchema.parse)

  const [result] = await useDb().insert(equipment).values({
    ...body,
    kurulumTarihi: body.kurulumTarihi ? new Date(body.kurulumTarihi) : undefined,
  })

  const [created] = await useDb().select().from(equipment).where(eq(equipment.id, result.insertId)).limit(1)
  setResponseStatus(event, 201)
  return created
})
