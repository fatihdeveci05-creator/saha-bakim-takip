import { and, eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment } from '../../database/schema'

// Pasif ekipman varsayılan olarak listelenmez — "silme" yerine önerilen
// pasife alma akışının işe yaraması için (yeni iş emri formu, Saha Durumu,
// Ekipmanlar listesi dahil hiçbir yerde önden çıkmasın). Geçmişi görmek
// isteyen (ör. Ekipmanlar sayfasında "Pasifleri göster") `includeInactive=1` gönderir.
export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const query = getQuery(event)
  const siteId = query.siteId ? Number(query.siteId) : undefined
  const includeInactive = query.includeInactive === '1' || query.includeInactive === 'true'

  const db = useDb()
  const conditions = []
  if (siteId) conditions.push(eq(equipment.siteId, siteId))
  if (!includeInactive) conditions.push(eq(equipment.aktif, true))

  if (conditions.length) {
    return db.select().from(equipment).where(and(...conditions))
  }
  return db.select().from(equipment)
})
