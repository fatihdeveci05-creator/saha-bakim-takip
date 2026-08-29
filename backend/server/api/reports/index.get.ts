import { eq, and, gte, lte } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users, workOrders, workOrderReviews, workOrderMaterials, materials } from '../../database/schema'

function avgHours(diffs: number[]) {
  if (!diffs.length) return null
  return diffs.reduce((a, b) => a + b, 0) / diffs.length
}

function hoursBetween(start: Date | null, end: Date | null) {
  if (!start || !end) return null
  const h = (end.getTime() - start.getTime()) / 3_600_000
  return h >= 0 ? h : null
}

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici', 'sorumlu'])
  const db = useDb()

  const query = getQuery(event)
  const from = query.from ? new Date(query.from as string) : undefined
  const to = query.to ? new Date(query.to as string) : undefined
  const validFrom = from && !Number.isNaN(from.getTime()) ? from : undefined
  const validTo = to && !Number.isNaN(to.getTime()) ? to : undefined

  const workOrderDateConditions = []
  if (validFrom) workOrderDateConditions.push(gte(workOrders.reportedAt, validFrom))
  if (validTo) workOrderDateConditions.push(lte(workOrders.reportedAt, validTo))

  const reviewDateConditions = []
  if (validFrom) reviewDateConditions.push(gte(workOrderReviews.incelenenZaman, validFrom))
  if (validTo) reviewDateConditions.push(lte(workOrderReviews.incelenenZaman, validTo))

  const [altYuklenicilar, allWorkOrders, allReviewsRaw, materialUsage] = await Promise.all([
    db
      .select({ id: users.id, ad: users.ad })
      .from(users)
      .where(eq(users.taraf, 'alt_yuklenici')),
    workOrderDateConditions.length
      ? db.select().from(workOrders).where(and(...workOrderDateConditions))
      : db.select().from(workOrders),
    (() => {
      const q = db
        .select({ sonuc: workOrderReviews.sonuc, atananUserId: workOrders.atananUserId })
        .from(workOrderReviews)
        .innerJoin(workOrders, eq(workOrders.id, workOrderReviews.workOrderId))
      return reviewDateConditions.length ? q.where(and(...reviewDateConditions)) : q
    })(),
    (() => {
      const q = db
        .select({
          materialId: workOrderMaterials.materialId,
          ad: materials.ad,
          birim: materials.birim,
          miktar: workOrderMaterials.miktar,
        })
        .from(workOrderMaterials)
        .innerJoin(materials, eq(materials.id, workOrderMaterials.materialId))
        .innerJoin(workOrders, eq(workOrders.id, workOrderMaterials.workOrderId))
      return workOrderDateConditions.length ? q.where(and(...workOrderDateConditions)) : q
    })(),
  ])

  // --- Personel performansı ---
  const personelPerformans = altYuklenicilar.map((u) => {
    const own = allWorkOrders.filter((w) => w.atananUserId === u.id)
    const mudahaleSaatleri = own.map((w) => hoursBetween(w.reportedAt, w.responseStartedAt)).filter((v): v is number => v !== null)
    const cozumSaatleri = own.map((w) => hoursBetween(w.reportedAt, w.resolvedAt)).filter((v): v is number => v !== null)
    return {
      userId: u.id,
      ad: u.ad,
      atananSayisi: own.length,
      onaylananSayisi: own.filter((w) => w.durum === 'onaylandi').length,
      reddedilenSayisi: own.filter((w) => w.durum === 'reddedildi').length,
      ortMudahaleSaat: avgHours(mudahaleSaatleri),
      ortCozumSaat: avgHours(cozumSaatleri),
    }
  })

  // --- Red oranı (genel + personel bazlı) ---
  const toplamDenetim = allReviewsRaw.length
  const toplamRed = allReviewsRaw.filter((r) => r.sonuc === 'red').length
  const redOraniByUser = altYuklenicilar.map((u) => {
    const own = allReviewsRaw.filter((r) => r.atananUserId === u.id)
    const red = own.filter((r) => r.sonuc === 'red').length
    return { userId: u.id, ad: u.ad, toplamDenetim: own.length, red, oran: own.length ? red / own.length : null }
  })

  // --- Malzeme tüketimi ---
  const malzemeMap = new Map<number, { ad: string; birim: string | null; toplamMiktar: number }>()
  for (const row of materialUsage) {
    const existing = malzemeMap.get(row.materialId)
    const miktar = Number.parseFloat(row.miktar)
    if (existing) {
      existing.toplamMiktar += miktar
    } else {
      malzemeMap.set(row.materialId, { ad: row.ad, birim: row.birim, toplamMiktar: miktar })
    }
  }
  const malzemeTuketimi = Array.from(malzemeMap.entries()).map(([materialId, v]) => ({ materialId, ...v }))

  return {
    personelPerformans,
    redOrani: {
      toplamDenetim,
      red: toplamRed,
      onay: toplamDenetim - toplamRed,
      oran: toplamDenetim ? toplamRed / toplamDenetim : null,
      byUser: redOraniByUser,
    },
    malzemeTuketimi,
  }
})
