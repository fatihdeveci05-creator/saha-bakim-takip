import { eq, and, gte, lte, inArray } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users, workOrders, workOrderReviews, workOrderMaterials, materials, equipment, sites } from '../../database/schema'

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
        .select({ sonuc: workOrderReviews.sonuc, resolvedByUserId: workOrders.resolvedByUserId })
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
  // NOT: atananUserId değil resolvedByUserId (kim fiilen çözdü) baz alınır —
  // Yüklenici başkasının işini tamamlayabiliyor, atanmamış (açık) işler de
  // uygun rol tarafından çözülebiliyor (atanan_user_id null kalsa bile),
  // dolayısıyla "kim ne kadar iş çıkardı" sorusunun doğru cevabı bu.
  const personelPerformans = altYuklenicilar.map((u) => {
    const atanan = allWorkOrders.filter((w) => w.atananUserId === u.id)
    const cozulen = allWorkOrders.filter((w) => w.resolvedByUserId === u.id)
    const mudahaleSaatleri = atanan
      .map((w) => hoursBetween(w.reportedAt, w.responseStartedAt))
      .filter((v): v is number => v !== null)
    const cozumSaatleri = cozulen.map((w) => hoursBetween(w.reportedAt, w.resolvedAt)).filter((v): v is number => v !== null)
    return {
      userId: u.id,
      ad: u.ad,
      atananSayisi: atanan.length,
      cozdugSayisi: cozulen.length,
      onaylananSayisi: cozulen.filter((w) => w.durum === 'onaylandi').length,
      reddedilenSayisi: cozulen.filter((w) => w.durum === 'reddedildi').length,
      ortMudahaleSaat: avgHours(mudahaleSaatleri),
      ortCozumSaat: avgHours(cozumSaatleri),
    }
  })

  // --- Red oranı (genel + personel bazlı) ---
  const toplamDenetim = allReviewsRaw.length
  const toplamRed = allReviewsRaw.filter((r) => r.sonuc === 'red').length
  const redOraniByUser = altYuklenicilar.map((u) => {
    const own = allReviewsRaw.filter((r) => r.resolvedByUserId === u.id)
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

  // --- Trendler (son 6 ay, üstteki tarih filtresinden BAĞIMSIZ — bir trendin
  // anlamlı olması için sabit bir pencereye ihtiyacı var) ---
  const trendStart = new Date()
  trendStart.setMonth(trendStart.getMonth() - 6)
  trendStart.setDate(1)
  trendStart.setHours(0, 0, 0, 0)

  const [trendWorkOrders, trendReviews] = await Promise.all([
    db
      .select({
        reportedAt: workOrders.reportedAt,
        responseStartedAt: workOrders.responseStartedAt,
        resolvedAt: workOrders.resolvedAt,
        tip: workOrders.tip,
        equipmentId: workOrders.equipmentId,
      })
      .from(workOrders)
      .where(gte(workOrders.reportedAt, trendStart)),
    db
      .select({ incelenenZaman: workOrderReviews.incelenenZaman, sonuc: workOrderReviews.sonuc })
      .from(workOrderReviews)
      .where(gte(workOrderReviews.incelenenZaman, trendStart)),
  ])

  function monthKey(d: Date) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  }

  const redOraniByMonth = new Map<string, { toplam: number; red: number }>()
  for (const r of trendReviews) {
    if (!r.incelenenZaman) continue
    const key = monthKey(r.incelenenZaman)
    const entry = redOraniByMonth.get(key) ?? { toplam: 0, red: 0 }
    entry.toplam += 1
    if (r.sonuc === 'red') entry.red += 1
    redOraniByMonth.set(key, entry)
  }

  const sureByMonth = new Map<string, { mudahale: number[]; cozum: number[] }>()
  for (const w of trendWorkOrders) {
    if (!w.reportedAt) continue
    const key = monthKey(w.reportedAt)
    const entry = sureByMonth.get(key) ?? { mudahale: [], cozum: [] }
    const m = hoursBetween(w.reportedAt, w.responseStartedAt)
    if (m !== null) entry.mudahale.push(m)
    const c = hoursBetween(w.reportedAt, w.resolvedAt)
    if (c !== null) entry.cozum.push(c)
    sureByMonth.set(key, entry)
  }

  const monthKeys = Array.from(new Set([...redOraniByMonth.keys(), ...sureByMonth.keys()])).sort()

  const redOraniTrend = monthKeys.map((period) => {
    const e = redOraniByMonth.get(period)
    return { period, toplamDenetim: e?.toplam ?? 0, red: e?.red ?? 0, oran: e && e.toplam ? e.red / e.toplam : null }
  })
  const sureTrend = monthKeys.map((period) => {
    const e = sureByMonth.get(period)
    return { period, ortMudahaleSaat: e ? avgHours(e.mudahale) : null, ortCozumSaat: e ? avgHours(e.cozum) : null }
  })

  // --- Tekrarlayan arızalar: son 90 günde aynı ekipmanda 2+ arıza bildirimi
  // — muhtemel kalıcı sorun/kötü onarım işareti, öne çıkarılır. ---
  const tekrarPenceresi = new Date()
  tekrarPenceresi.setDate(tekrarPenceresi.getDate() - 90)
  const arizaByEquipment = new Map<number, Date[]>()
  for (const w of trendWorkOrders) {
    if (w.tip !== 'ariza' || !w.reportedAt || w.reportedAt < tekrarPenceresi) continue
    const list = arizaByEquipment.get(w.equipmentId) ?? []
    list.push(w.reportedAt)
    arizaByEquipment.set(w.equipmentId, list)
  }
  const tekrarlayanGruplar = Array.from(arizaByEquipment.entries()).filter(([, dates]) => dates.length >= 2)

  let tekrarlayanArizalar: {
    equipmentId: number
    siteAd: string
    ekipmanLabel: string
    sonDoksanGunArizaSayisi: number
    sonArizaTarihi: Date
  }[] = []
  if (tekrarlayanGruplar.length) {
    const [equipmentRows, siteRows] = await Promise.all([
      db
        .select({ id: equipment.id, tip: equipment.tip, marka: equipment.marka, model: equipment.model, siteId: equipment.siteId })
        .from(equipment)
        .where(inArray(equipment.id, tekrarlayanGruplar.map(([id]) => id))),
      db.select({ id: sites.id, ad: sites.ad }).from(sites),
    ])
    const siteNameById = new Map(siteRows.map((s) => [s.id, s.ad]))
    const equipmentById = new Map(equipmentRows.map((e) => [e.id, e]))
    tekrarlayanArizalar = tekrarlayanGruplar
      .map(([equipmentId, dates]) => {
        const eq = equipmentById.get(equipmentId)
        const sonArizaTarihi = dates.reduce((a, b) => (b > a ? b : a))
        return {
          equipmentId,
          siteAd: eq ? (siteNameById.get(eq.siteId) ?? `Saha #${eq.siteId}`) : `Ekipman #${equipmentId}`,
          ekipmanLabel: eq
            ? `${eq.tip === 'asansor' ? 'Asansör' : 'Yürüyen Merdiven'} — ${eq.marka ?? ''} ${eq.model ?? ''}`.trim()
            : '',
          sonDoksanGunArizaSayisi: dates.length,
          sonArizaTarihi,
        }
      })
      .sort((a, b) => b.sonDoksanGunArizaSayisi - a.sonDoksanGunArizaSayisi)
  }

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
    redOraniTrend,
    sureTrend,
    tekrarlayanArizalar,
  }
})
