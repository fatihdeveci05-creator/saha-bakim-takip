import { eq, and } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { safeUserColumns } from '../../utils/selectors'
import { getUserTeamId } from '../../utils/teamScope'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)

  if (payload.rol === 'yonetici' || payload.rol === 'denetci') {
    return useDb().select(safeUserColumns).from(users)
  }

  // Sorumlu, iş atayabilmek için sadece KENDİ EKİBİNDEKİ alt yüklenici
  // personeli görür (işveren tarafını ve diğer ekipleri görmez).
  if (payload.rol === 'sorumlu') {
    const ownTeamId = await getUserTeamId(Number(payload.sub))
    if (!ownTeamId) return []
    return useDb()
      .select(safeUserColumns)
      .from(users)
      .where(and(eq(users.taraf, 'alt_yuklenici'), eq(users.takimId, ownTeamId)))
  }

  throw createError({ statusCode: 403, statusMessage: 'Bu işlem için yetkiniz yok' })
})
