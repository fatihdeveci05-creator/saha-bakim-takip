import { z } from 'zod'
import { verifyToken, signAccessToken } from '../../utils/jwt'

const bodySchema = z.object({
  refreshToken: z.string().min(1),
})

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, bodySchema.parse)

  let payload
  try {
    payload = await verifyToken(body.refreshToken)
  } catch {
    throw createError({ statusCode: 401, statusMessage: 'Geçersiz veya süresi dolmuş refresh token' })
  }

  const accessToken = await signAccessToken(payload)
  return { accessToken }
})
