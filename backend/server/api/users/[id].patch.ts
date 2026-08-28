import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users, tarafEnum, rolEnum } from '../../database/schema'
import { safeUserColumns } from '../../utils/selectors'

const bodySchema = z.object({
  ad: z.string().min(1).optional(),
  telefon: z.string().optional(),
  taraf: z.enum(tarafEnum).optional(),
  rol: z.enum(rolEnum).optional(),
  aktif: z.boolean().optional(),
  takimId: z.number().int().nullable().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const [existing] = await useDb().select({ id: users.id }).from(users).where(eq(users.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Kullanıcı bulunamadı' })
  }

  await useDb().update(users).set(body).where(eq(users.id, id))

  const [updated] = await useDb().select(safeUserColumns).from(users).where(eq(users.id, id)).limit(1)
  return updated
})
