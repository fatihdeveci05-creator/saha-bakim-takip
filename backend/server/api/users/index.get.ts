import { eq, and } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { safeUserColumns } from '../../utils/selectors'
import { getUserTeamId } from '../../utils/teamScope'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const query = getQuery(event)
  // Personel yönetimi (günlük görev ataması — rol/takım değiştirme) için
  // Yüklenici'nin TÜM saha personelini görmesi gerekir, sadece kendi
  // ekibini değil — aksi halde başka ekipteki birini göremez/kendi
  // ekibine alamaz. İş atarken (assign_work_order_screen) ise bu
  // parametre GÖNDERİLMEZ, çünkü orada sadece kendi ekibi listelenmeli
  // (atayamayacağı biri listede görünmesin diye).
  const tumSahaPersoneli = query.scope === 'tumSahaPersoneli'

  if (payload.rol === 'yonetici' || payload.rol === 'denetci') {
    return useDb().select(safeUserColumns).from(users)
  }

  if (payload.rol === 'sorumlu') {
    if (tumSahaPersoneli) {
      return useDb().select(safeUserColumns).from(users).where(eq(users.taraf, 'alt_yuklenici'))
    }
    // Sorumlu, iş atayabilmek için sadece KENDİ EKİBİNDEKİ alt yüklenici
    // personeli görür (işveren tarafını ve diğer ekipleri görmez).
    const ownTeamId = await getUserTeamId(Number(payload.sub))
    if (!ownTeamId) return []
    return useDb()
      .select(safeUserColumns)
      .from(users)
      .where(and(eq(users.taraf, 'alt_yuklenici'), eq(users.takimId, ownTeamId)))
  }

  throw createError({ statusCode: 403, statusMessage: 'Bu işlem için yetkiniz yok' })
})
