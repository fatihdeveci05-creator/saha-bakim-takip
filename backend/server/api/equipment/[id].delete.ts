import { count, eq } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { equipment, workOrders } from '../../database/schema'

// Sadece Yönetici (İşveren) silebilir. İş emri geçmişi olan bir ekipman
// silinemez — künye/geçmiş kaybolmasın diye. Bunun yerine PATCH ile
// `aktif:false` yapılarak Kontrol Ekibi konum akışından çıkarılabilir.
export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))

  const db = useDb()
  const [existing] = await db.select({ id: equipment.id }).from(equipment).where(eq(equipment.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Ekipman bulunamadı' })
  }

  const [{ value: workOrderCount }] = await db.select({ value: count() }).from(workOrders).where(eq(workOrders.equipmentId, id))
  if (workOrderCount > 0) {
    throw createError({
      statusCode: 409,
      statusMessage: `Bu ekipmanla ilgili ${workOrderCount} iş emri kaydı var, silinemez — bunun yerine pasife alabilirsiniz`,
    })
  }

  await db.delete(equipment).where(eq(equipment.id, id))
  return { success: true }
})
