import { and, eq } from 'drizzle-orm'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { workOrders, isEmriDurumEnum } from '../../database/schema'
import { canViewAllWorkOrders } from '../../utils/workOrderAccess'

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const query = getQuery(event)
  const durum = query.durum as (typeof isEmriDurumEnum)[number] | undefined

  const conditions = []
  if (!canViewAllWorkOrders(payload)) {
    conditions.push(eq(workOrders.atananUserId, Number(payload.sub)))
  }
  if (durum && isEmriDurumEnum.includes(durum)) {
    conditions.push(eq(workOrders.durum, durum))
  }

  const db = useDb()
  if (conditions.length) {
    return db.select().from(workOrders).where(and(...conditions))
  }
  return db.select().from(workOrders)
})
