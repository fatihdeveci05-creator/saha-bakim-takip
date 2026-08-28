import { randomUUID } from 'node:crypto'
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { requireAuth } from '../utils/auth'

const ALLOWED_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

// Yerel geliştirme/MVP için basit disk depolama. Üretimde PLAN.md'deki ayrı
// Hetzner Volume'e (public/uploads yerine) taşınacak.
export default defineEventHandler(async (event) => {
  await requireAuth(event)

  const parts = await readMultipartFormData(event)
  const file = parts?.find((p) => p.name === 'file')
  if (!file || !file.data.length) {
    throw createError({ statusCode: 400, statusMessage: 'Dosya bulunamadı' })
  }

  const ext = ALLOWED_TYPES[file.type ?? '']
  if (!ext) {
    throw createError({ statusCode: 400, statusMessage: 'Sadece jpeg/png/webp kabul edilir' })
  }

  const uploadsDir = join(process.cwd(), 'public', 'uploads')
  await mkdir(uploadsDir, { recursive: true })

  const filename = `${randomUUID()}.${ext}`
  await writeFile(join(uploadsDir, filename), file.data)

  return { url: `/uploads/${filename}` }
})
