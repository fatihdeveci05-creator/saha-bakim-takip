import { eq, and, inArray } from 'drizzle-orm'
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
    'ABB Kontrol',
    mesaj,
    relatedWorkOrderId ? { workOrderId: String(relatedWorkOrderId) } : undefined,
  )
}

export async function notifyUser(userId: number, tip: string, mesaj: string, relatedWorkOrderId?: number) {
  await useDb().insert(notifications).values({ userId, tip, mesaj, relatedWorkOrderId })
  await pushToUsers([userId], mesaj, relatedWorkOrderId)
}

// Yeni arıza bildirildiğinde tüm aktif yöneticilere bildirim gider.
export async function notifyYoneticiler(tip: string, mesaj: string, relatedWorkOrderId?: number) {
  const db = useDb()
  const yoneticiler = await db
    .select({ id: users.id })
    .from(users)
    .where(and(eq(users.taraf, 'isveren'), eq(users.rol, 'yonetici'), eq(users.aktif, true)))

  if (!yoneticiler.length) return
  await db.insert(notifications).values(yoneticiler.map((y) => ({ userId: y.id, tip, mesaj, relatedWorkOrderId })))
  await pushToUsers(
    yoneticiler.map((y) => y.id),
    mesaj,
    relatedWorkOrderId,
  )
}
