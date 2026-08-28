import { eq } from 'drizzle-orm'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { requireAuth } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)

  const [user] = await useDb()
    .select({
      id: users.id,
      ad: users.ad,
      email: users.email,
      telefon: users.telefon,
      taraf: users.taraf,
      rol: users.rol,
      aktif: users.aktif,
    })
    .from(users)
    .where(eq(users.id, Number(payload.sub)))
    .limit(1)

  if (!user) {
    throw createError({ statusCode: 404, statusMessage: 'Kullanıcı bulunamadı' })
  }

  return user
})
