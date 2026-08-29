import { count, eq } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { teams, users } from '../../database/schema'

// Sadece Yönetici (İşveren) silebilir. Atanmış personeli olan bir ekip
// silinemez — önce personelin başka bir ekibe taşınması/ekipten çıkarılması gerekir.
export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici'])
  const id = Number(getRouterParam(event, 'id'))

  const db = useDb()
  const [existing] = await db.select({ id: teams.id }).from(teams).where(eq(teams.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Ekip bulunamadı' })
  }

  const [{ value: memberCount }] = await db.select({ value: count() }).from(users).where(eq(users.takimId, id))
  if (memberCount > 0) {
    throw createError({
      statusCode: 409,
      statusMessage: `Bu ekibe atanmış ${memberCount} personel var — önce personeli başka ekibe taşıyın veya ekipten çıkarın`,
    })
  }

  await db.delete(teams).where(eq(teams.id, id))
  return { success: true }
})
