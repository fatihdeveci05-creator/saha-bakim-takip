import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { safeUserColumns } from '../../utils/selectors'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)

  if (payload.rol === 'yonetici' || payload.rol === 'denetci') {
    return useDb().select(safeUserColumns).from(users)
  }

  // Sorumlu, iş atayabilmek için sadece alt yüklenici ekip listesini görür
  // (işveren tarafı kullanıcılarının iletişim bilgilerini görmez).
  if (payload.rol === 'sorumlu') {
    return useDb().select(safeUserColumns).from(users).where(eq(users.taraf, 'alt_yuklenici'))
  }

  throw createError({ statusCode: 403, statusMessage: 'Bu işlem için yetkiniz yok' })
})
