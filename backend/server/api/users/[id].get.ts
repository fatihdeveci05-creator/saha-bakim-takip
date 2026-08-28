import { eq } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { safeUserColumns } from '../../utils/selectors'

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici', 'denetci'])
  const id = Number(getRouterParam(event, 'id'))

  const [user] = await useDb()
    .select(safeUserColumns)
    .from(users)
    .where(eq(users.id, id))
    .limit(1)

  if (!user) {
    throw createError({ statusCode: 404, statusMessage: 'Kullanıcı bulunamadı' })
  }
  return user
})
