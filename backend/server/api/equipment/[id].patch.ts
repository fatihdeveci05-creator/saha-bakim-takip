import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment, ekipmanTipEnum } from '../../database/schema'

const bodySchema = z.object({
  siteId: z.number().int().optional(),
  tip: z.enum(ekipmanTipEnum).optional(),
  marka: z.string().optional(),
  model: z.string().optional(),
  seriNo: z.string().optional(),
  kurulumTarihi: z.string().datetime().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const [existing] = await useDb().select({ id: equipment.id }).from(equipment).where(eq(equipment.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Ekipman bulunamadı' })
  }

  await useDb()
    .update(equipment)
    .set({
      ...body,
      kurulumTarihi: body.kurulumTarihi ? new Date(body.kurulumTarihi) : undefined,
    })
    .where(eq(equipment.id, id))

  const [updated] = await useDb().select().from(equipment).where(eq(equipment.id, id)).limit(1)
  return updated
})
