import { createReadStream } from 'node:fs'
import { stat } from 'node:fs/promises'
import { join, normalize, sep } from 'node:path'

const CONTENT_TYPES: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
}

// Neden ayrı bir route: bkz. server/api/uploads.post.ts üstündeki not —
// yüklenen dosyalar public/ dışında (uploads/) tutulur, Nitro'nun otomatik
// statik dosya servisi onları bulamaz, bu yüzden burada elle serve edilir.
export default defineEventHandler(async (event) => {
  const rawPath = getRouterParam(event, 'path') ?? ''
  const filename = normalize(rawPath).replace(/^(\.\.(\/|\\|$))+/, '')

  // Alt klasör yok (upload her zaman tek dosya adı üretir) — path traversal'a karşı.
  if (!filename || filename.includes('..') || filename.includes(sep)) {
    throw createError({ statusCode: 400, statusMessage: 'Geçersiz dosya yolu' })
  }

  const ext = filename.slice(filename.lastIndexOf('.')).toLowerCase()
  const contentType = CONTENT_TYPES[ext]
  if (!contentType) {
    throw createError({ statusCode: 400, statusMessage: 'Desteklenmeyen dosya türü' })
  }

  const filePath = join(process.cwd(), 'uploads', filename)
  try {
    await stat(filePath)
  } catch {
    throw createError({ statusCode: 404, statusMessage: 'Dosya bulunamadı' })
  }

  setHeader(event, 'Content-Type', contentType)
  setHeader(event, 'Cache-Control', 'public, max-age=31536000, immutable')
  return sendStream(event, createReadStream(filePath))
})
