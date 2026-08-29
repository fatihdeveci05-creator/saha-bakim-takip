import { count, eq } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import {
  users,
  workOrders,
  workOrderReviews,
  workOrderPhotos,
  workOrderTimeline,
  deviceTokens,
  notifications,
  userLocations,
  teams,
  sites,
} from '../../database/schema'

// Sadece Yönetici (İşveren) silebilir. İş geçmişi (atanmış/çözmüş/fotoğraf
// yüklemiş/denetlemiş) olan bir kullanıcı silinemez — geçmişteki "kim
// yaptı" bilgisi kaybolmasın diye (bkz. PLAN.md append-only tasarım
// felsefesi). Bunun yerine PATCH ile `aktif:false` yapılmalı (zaten mevcut).
// Geçmişi olmayan (yeni açılmış, hiç iş yapmamış) bir hesap gerçekten
// silinebilir — bu durumda cihaz token'ı/bildirim/konum gibi kendisine ait
// zararsız (denetim açısından önemsiz) kayıtlar da birlikte temizlenir.
export default defineEventHandler(async (event) => {
  const actor = await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))

  if (Number(actor.sub) === id) {
    throw createError({ statusCode: 400, statusMessage: 'Kendi hesabınızı silemezsiniz' })
  }

  const db = useDb()
  const [existing] = await db.select({ id: users.id }).from(users).where(eq(users.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Kullanıcı bulunamadı' })
  }

  const [
    [{ value: atananSayisi }],
    [{ value: cozdugSayisi }],
    [{ value: reviewSayisi }],
    [{ value: fotoSayisi }],
    [{ value: timelineSayisi }],
  ] = await Promise.all([
    db.select({ value: count() }).from(workOrders).where(eq(workOrders.atananUserId, id)),
    db.select({ value: count() }).from(workOrders).where(eq(workOrders.resolvedByUserId, id)),
    db.select({ value: count() }).from(workOrderReviews).where(eq(workOrderReviews.reviewerUserId, id)),
    db.select({ value: count() }).from(workOrderPhotos).where(eq(workOrderPhotos.yukleyenUserId, id)),
    db.select({ value: count() }).from(workOrderTimeline).where(eq(workOrderTimeline.createdByUserId, id)),
  ])
  const gecmisSayisi = atananSayisi + cozdugSayisi + reviewSayisi + fotoSayisi + timelineSayisi
  if (gecmisSayisi > 0) {
    throw createError({
      statusCode: 409,
      statusMessage: `Bu kullanıcının iş geçmişi var (${gecmisSayisi} kayıt), silinemez — bunun yerine pasife alabilirsiniz`,
    })
  }

  // Geçmişi yok — kendisine ait zararsız kayıtları temizleyip hesabı sil.
  await Promise.all([
    db.delete(deviceTokens).where(eq(deviceTokens.userId, id)),
    db.delete(notifications).where(eq(notifications.userId, id)),
    db.delete(userLocations).where(eq(userLocations.userId, id)),
    db.update(teams).set({ sorumluUserId: null }).where(eq(teams.sorumluUserId, id)),
    db.update(sites).set({ denetciUserId: null }).where(eq(sites.denetciUserId, id)),
  ])
  await db.delete(users).where(eq(users.id, id))

  return { success: true }
})
