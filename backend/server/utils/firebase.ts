import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { eq } from 'drizzle-orm'
import { initializeApp, cert, getApps } from 'firebase-admin/app'
import { getMessaging } from 'firebase-admin/messaging'
import { useDb } from '../database/client'
import { deviceTokens } from '../database/schema'

const keyPath = join(process.cwd(), 'firebase-service-account.json')
let checked = false
let available = false

function ensureInitialized() {
  if (checked) return available
  checked = true
  if (!existsSync(keyPath)) {
    console.warn('[firebase] firebase-service-account.json bulunamadı, push bildirim gönderimi devre dışı')
    return false
  }
  if (!getApps().length) {
    initializeApp({ credential: cert(keyPath) })
  }
  available = true
  return true
}

export async function sendPush(tokens: string[], title: string, body: string, data?: Record<string, string>) {
  if (!tokens.length || !ensureInitialized()) return
  try {
    const res = await getMessaging().sendEachForMulticast({ tokens, notification: { title, body }, data })
    console.log(`[firebase] push gönderildi: ${res.successCount} başarılı, ${res.failureCount} başarısız`)

    const deadTokens: string[] = []
    res.responses.forEach((r, i) => {
      if (r.success) return
      const code = r.error?.code
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        deadTokens.push(tokens[i]!)
      } else {
        console.error(`[firebase] gönderim hatası (${tokens[i]}):`, code, r.error?.message)
      }
    })

    if (deadTokens.length) {
      // Geçersiz/artık kayıtlı olmayan token'ları temizle, tekrar denenmesin.
      await Promise.all(deadTokens.map((t) => useDb().delete(deviceTokens).where(eq(deviceTokens.token, t))))
    }
  } catch (err) {
    console.error('[firebase] push gönderilemedi', err)
  }
}
