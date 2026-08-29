import { eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { sites } from '../../database/schema'

// Pasif saha varsayılan olarak listelenmez — "silme" yerine önerilen pasife
// alma akışının işe yaraması için (yeni ekipman formu, Saha Durumu/Haritası
// dahil hiçbir yerde önden çıkmasın). `includeInactive=1` hepsini döner.
export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const query = getQuery(event)
  const includeInactive = query.includeInactive === '1' || query.includeInactive === 'true'

  const db = useDb()
  if (!includeInactive) {
    return db.select().from(sites).where(eq(sites.aktif, true))
  }
  return db.select().from(sites)
})
