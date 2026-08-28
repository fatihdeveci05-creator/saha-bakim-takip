import { and, eq, gte, lte } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { workOrders, isEmriDurumEnum } from '../../database/schema'
import { canViewAllWorkOrders } from '../../utils/workOrderAccess'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const query = getQuery(event)
  const durum = query.durum as (typeof isEmriDurumEnum)[number] | undefined
  const from = query.from ? new Date(query.from as string) : undefined
  const to = query.to ? new Date(query.to as string) : undefined

  const conditions = []
  if (!canViewAllWorkOrders(payload)) {
    conditions.push(eq(workOrders.atananUserId, Number(payload.sub)))
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
  if (conditions.length) {
    return db.select().from(workOrders).where(and(...conditions))
  }
  return db.select().from(workOrders)
})
