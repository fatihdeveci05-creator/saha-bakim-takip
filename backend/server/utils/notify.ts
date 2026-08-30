import { eq, and, or, inArray, ne } from 'drizzle-orm'
import { useDb } from '../database/client'
import { notifications, users, deviceTokens } from '../database/schema'
import { sendPush } from './firebase'

async function pushToUsers(userIds: number[], mesaj: string, relatedWorkOrderId?: number) {
  if (!userIds.length) return
  const tokens = await useDb()
    .select({ token: deviceTokens.token })
    .from(deviceTokens)
    .where(inArray(deviceTokens.userId, userIds))
  if (!tokens.length) return
  await sendPush(
    tokens.map((t) => t.token),
    'SahaCheck',
    mesaj,
    relatedWorkOrderId ? { workOrderId: String(relatedWorkOrderId) } : undefined,
  )
}

// Bildirim gönderimi (DB kaydı + push) bilinçli olarak sessiz-başarısız —
// çağıran endpoint'ler (ör. arıza bildirme, iş atama) genelde bildirimden
// ÖNCE asıl işi (iş emri oluşturma vb.) zaten kalıcı olarak kaydediyor.
// Burada bir hata (ör. geçici DB bağlantı kopması) fırlatılırsa, o zaten
// başarılı olmuş asıl işlem de istemciye "başarısız" gibi görünür — kullanıcı
// tekrar dener ve mükerrer kayıt oluşturur. Bildirim ikincil bir yan etki,
// asıl işlemin başarısını asla etkilememeli.
export async function notifyUser(userId: number, tip: string, mesaj: string, relatedWorkOrderId?: number) {
  try {
    await useDb().insert(notifications).values({ userId, tip, mesaj, relatedWorkOrderId })
    await pushToUsers([userId], mesaj, relatedWorkOrderId)
  } catch (err) {
    console.error('[notify] notifyUser başarısız, asıl işlem etkilenmedi', err)
  }
}

// Yeni/değişen bir iş emri olduğunda (arıza bildirimi, atama, sonradan atama)
// hem İşveren (yonetici) hem Yüklenici (sorumlu) tarafı bilgilendirilir —
// ikisi de PLAN.md'ye göre "tüm sahayı görme" yetkisine sahip. İşlemi
// başlatan kişiye (excludeUserId) kendi eylemi için bildirim gitmez.
export async function notifyIsverenVeYuklenici(
  tip: string,
  mesaj: string,
  relatedWorkOrderId?: number,
  excludeUserId?: number,
) {
  try {
    const db = useDb()
    const conditions = [
      and(eq(users.taraf, 'isveren'), eq(users.rol, 'yonetici')),
      and(eq(users.taraf, 'alt_yuklenici'), eq(users.rol, 'sorumlu')),
    ]
    const whereClause = and(eq(users.aktif, true), or(...conditions), excludeUserId ? ne(users.id, excludeUserId) : undefined)
    const alicilar = await db.select({ id: users.id }).from(users).where(whereClause)

    if (!alicilar.length) return
    await db.insert(notifications).values(alicilar.map((a) => ({ userId: a.id, tip, mesaj, relatedWorkOrderId })))
    await pushToUsers(
      alicilar.map((a) => a.id),
      mesaj,
      relatedWorkOrderId,
    )
  } catch (err) {
    console.error('[notify] notifyIsverenVeYuklenici başarısız, asıl işlem etkilenmedi', err)
  }
}
