import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users, tarafEnum, rolEnum } from '../../database/schema'
import { hashPassword } from '../../utils/password'
import { safeUserColumns } from '../../utils/selectors'

const bodySchema = z.object({
  ad: z.string().min(1),
  email: z.string().email(),
  telefon: z.string().optional(),
  password: z.string().min(8),
  taraf: z.enum(tarafEnum),
  rol: z.enum(rolEnum),
  takimId: z.number().int().optional(),
})

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const body = await readValidatedBody(event, bodySchema.parse)

  const [existing] = await useDb()
    .select({ id: users.id })
    .from(users)
    .where(eq(users.email, body.email))
    .limit(1)
  if (existing) {
    throw createError({ statusCode: 409, statusMessage: 'Bu e-posta zaten kayıtlı' })
  }

  const passwordHash = await hashPassword(body.password)
  const [result] = await useDb().insert(users).values({
    ad: body.ad,
    email: body.email,
    telefon: body.telefon,
    passwordHash,
    taraf: body.taraf,
    rol: body.rol,
    takimId: body.takimId,
  })

  const [created] = await useDb()
    .select(safeUserColumns)
    .from(users)
    .where(eq(users.id, result.insertId))
    .limit(1)

  setResponseStatus(event, 201)
  return created
})
