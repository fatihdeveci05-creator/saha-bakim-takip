import { and, desc, eq, ne } from 'drizzle-orm'
import { alias } from 'drizzle-orm/mysql-core'
import { requireAuth } from '../../../utils/auth'
import { useDb } from '../../../database/client'
import { workOrders, users } from '../../../database/schema'

const resolvedBy = alias(users, 'resolvedBy')

// "Ünite künyesi" — bir ekipmanın geçmişi (arıza+bakım). Normal iş emri listeleme
// rol/tipe göre kısıtlıyken (bkz. workOrderAccess), bu endpoint bilinçli olarak geniş:
// Bakım Ekibi'nin, gittiği ekipmanda Arıza Ekibi'nin bıraktığı geçmiş notları
// görebilmesi için var (PLAN.md böl. 2). Herkese açık salt okunur referans veri —
// düzenleme yetkisi vermiyor. Kontrol Ekibi'nin sorun görmediği rutin "Sorun Yok"
// kayıtları (tip='kontrol') bilinçli olarak dışlanıyor — künye gereksiz kayıtla
// dolmasın diye (bkz. GET /api/kontrol/check, her zaman durum=onaylandi ile kapanır).
export default defineEventHandler(async (event) => {
  await requireAuth(event)
  const equipmentId = Number(getRouterParam(event, 'id'))

  return useDb()
    .select({
      id: workOrders.id,
      tip: workOrders.tip,
      durum: workOrders.durum,
      aciklama: workOrders.aciklama,
      reportedAt: workOrders.reportedAt,
      resolvedAt: workOrders.resolvedAt,
      resolvedByUserId: workOrders.resolvedByUserId,
      resolvedByAd: resolvedBy.ad,
    })
    .from(workOrders)
    .leftJoin(resolvedBy, eq(resolvedBy.id, workOrders.resolvedByUserId))
    .where(and(eq(workOrders.equipmentId, equipmentId), ne(workOrders.tip, 'kontrol')))
    .orderBy(desc(workOrders.reportedAt))
})
