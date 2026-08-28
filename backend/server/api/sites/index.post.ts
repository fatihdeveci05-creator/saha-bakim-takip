import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { sites } from '../../database/schema'

const bodySchema = z.object({
  ad: z.string().min(1),
  adres: z.string().optional(),
  lat: z.number().optional(),
  lng: z.number().optional(),
  denetciUserId: z.number().int().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const body = await readValidatedBody(event, bodySchema.parse)

  const [result] = await useDb().insert(sites).values({
    ad: body.ad,
    adres: body.adres,
    lat: body.lat !== undefined ? String(body.lat) : undefined,
    lng: body.lng !== undefined ? String(body.lng) : undefined,
    denetciUserId: body.denetciUserId,
  })

  const [created] = await useDb().select().from(sites).where(eq(sites.id, result.insertId)).limit(1)
  setResponseStatus(event, 201)
  return created
})
