import { count, eq } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { sites, equipment } from '../../database/schema'

// Sadece Yönetici (İşveren) silebilir. Ekipmanı olan bir saha silinemez —
// önce ekipmanların silinmesi/başka sahaya taşınması gerekir (yanlışlıkla
// tüm ekipman geçmişi kaybolmasın diye).
export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))

  const db = useDb()
  const [existing] = await db.select({ id: sites.id }).from(sites).where(eq(sites.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Saha bulunamadı' })
  }

  const [{ value: equipmentCount }] = await db.select({ value: count() }).from(equipment).where(eq(equipment.siteId, id))
  if (equipmentCount > 0) {
    throw createError({
      statusCode: 409,
      statusMessage: `Bu sahada ${equipmentCount} ekipman var — önce ekipmanları silin veya başka sahaya taşıyın`,
    })
  }

  await db.delete(sites).where(eq(sites.id, id))
  return { success: true }
})
