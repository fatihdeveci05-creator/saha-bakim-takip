import { z } from 'zod'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { userLocations } from '../../database/schema'

const bodySchema = z.object({
  lat: z.number(),
  lng: z.number(),
})

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  if (payload.taraf !== 'alt_yuklenici') {
    throw createError({ statusCode: 403, statusMessage: 'Sadece alt yüklenici personeli konum gönderebilir' })
  }
  const body = await readValidatedBody(event, bodySchema.parse)

  const userId = Number(payload.sub)
  const lat = String(body.lat)
  const lng = String(body.lng)

  await useDb()
    .insert(userLocations)
    .values({ userId, lat, lng })
    .onDuplicateKeyUpdate({ set: { lat, lng, updatedAt: new Date() } })

  return { ok: true }
})
