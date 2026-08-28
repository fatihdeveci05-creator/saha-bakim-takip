import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { verifyPassword } from '../../utils/password'
import { signAccessToken, signRefreshToken } from '../../utils/jwt'

const bodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
})

export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, bodySchema.parse)

  const [user] = await useDb()
    .select()
    .from(users)
    .where(eq(users.email, body.email))
    .limit(1)

  if (!user || !user.aktif) {
    throw createError({ statusCode: 401, statusMessage: 'E-posta veya şifre hatalı' })
  }

  const passwordOk = await verifyPassword(body.password, user.passwordHash)
  if (!passwordOk) {
    throw createError({ statusCode: 401, statusMessage: 'E-posta veya şifre hatalı' })
  }

  const payload = { sub: String(user.id), taraf: user.taraf, rol: user.rol }
  const [accessToken, refreshToken] = await Promise.all([
    signAccessToken(payload),
    signRefreshToken(payload),
  ])

  return {
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      ad: user.ad,
      email: user.email,
      taraf: user.taraf,
      rol: user.rol,
    },
  }
})
