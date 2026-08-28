import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { sites } from '../../database/schema'

const bodySchema = z.object({
  ad: z.string().min(1).optional(),
  adres: z.string().optional(),
  lat: z.number().optional(),
  lng: z.number().optional(),
  denetciUserId: z.number().int().nullable().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const [existing] = await useDb().select({ id: sites.id }).from(sites).where(eq(sites.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Saha bulunamadı' })
  }

  await useDb()
    .update(sites)
    .set({
      ...body,
      lat: body.lat !== undefined ? String(body.lat) : undefined,
      lng: body.lng !== undefined ? String(body.lng) : undefined,
    })
    .where(eq(sites.id, id))

  const [updated] = await useDb().select().from(sites).where(eq(sites.id, id)).limit(1)
  return updated
})
