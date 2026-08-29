import { and, eq, gte, lte, inArray, notInArray, getTableColumns } from 'drizzle-orm'
import { alias } from 'drizzle-orm/mysql-core'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { workOrders, isEmriDurumEnum, users } from '../../database/schema'
import { canViewAllWorkOrders, visibleTipsFor } from '../../utils/workOrderAccess'

const atanan = alias(users, 'atanan')
const resolvedBy = alias(users, 'resolvedBy')

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const query = getQuery(event)
  const durum = query.durum as (typeof isEmriDurumEnum)[number] | undefined
  const from = query.from ? new Date(query.from as string) : undefined
  const to = query.to ? new Date(query.to as string) : undefined

  const conditions = []
  if (!canViewAllWorkOrders(payload)) {
    const tips = visibleTipsFor(payload)
    if (tips) {
      conditions.push(inArray(workOrders.tip, tips as (typeof workOrders.$inferSelect)['tip'][]))
    }
    // Kontrol Ekibi'nin geçmişe (kapanmış kayıtlara) erişimi yok — sadece açık kayıtlar.
    if (payload.rol === 'kontrol_ekibi') {
      conditions.push(notInArray(workOrders.durum, ['onaylandi', 'reddedildi']))
    }
  }
  if (durum && isEmriDurumEnum.includes(durum)) {
    conditions.push(eq(workOrders.durum, durum))
  }
  if (from && !Number.isNaN(from.getTime())) {
    conditions.push(gte(workOrders.reportedAt, from))
  }
  if (to && !Number.isNaN(to.getTime())) {
    conditions.push(lte(workOrders.reportedAt, to))
  }

  const db = useDb()
  // Atanan ve çözen personelin adı — listede/denetim kuyruğunda tekil kullanıcı
  // sorgusu yapmaya gerek kalmasın diye burada join ediliyor.
  const query_ = db
    .select({
      ...getTableColumns(workOrders),
      atananAd: atanan.ad,
      resolvedByAd: resolvedBy.ad,
    })
    .from(workOrders)
    .leftJoin(atanan, eq(atanan.id, workOrders.atananUserId))
    .leftJoin(resolvedBy, eq(resolvedBy.id, workOrders.resolvedByUserId))

  if (conditions.length) {
    return query_.where(and(...conditions))
  }
  return query_
})
