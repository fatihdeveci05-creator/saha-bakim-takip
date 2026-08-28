import { z } from 'zod'
import { requireAuth } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { deviceTokens } from '../../../database/schema'

const bodySchema = z.object({
  token: z.string().min(1),
  platform: z.enum(['android', 'ios', 'web']).optional(),
})

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const body = await readValidatedBody(event, bodySchema.parse)
  const userId = Number(payload.sub)

  await useDb()
    .insert(deviceTokens)
    .values({ userId, token: body.token, platform: body.platform })
    .onDuplicateKeyUpdate({ set: { userId, platform: body.platform } })

  return { ok: true }
})
