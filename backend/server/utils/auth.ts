import type { H3Event } from 'h3'
import { verifyToken, type AuthTokenPayload } from './jwt'

export async function requireAuth(event: H3Event): Promise<AuthTokenPayload> {
  const header = getHeader(event, 'authorization')
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined
  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Yetkilendirme gerekli' })
  }
  try {
    return await verifyToken(token)
  } catch {
    throw createError({ statusCode: 401, statusMessage: 'Geçersiz veya süresi dolmuş token' })
  }
}

export async function requireRole(event: H3Event, allowedRoles: string[]) {
  const payload = await requireAuth(event)
  if (!allowedRoles.includes(payload.rol)) {
    throw createError({ statusCode: 403, statusMessage: 'Bu işlem için yetkiniz yok' })
  }
  return payload
}
