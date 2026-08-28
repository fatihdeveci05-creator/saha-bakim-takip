import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { initializeApp, cert, getApps } from 'firebase-admin/app'
import { getMessaging } from 'firebase-admin/messaging'

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
    await getMessaging().sendEachForMulticast({ tokens, notification: { title, body }, data })
  } catch (err) {
    console.error('[firebase] push gönderilemedi', err)
  }
}
