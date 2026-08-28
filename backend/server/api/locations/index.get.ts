import { eq } from 'drizzle-orm'
import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { userLocations, users } from '../../database/schema'

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici', 'denetci'])

  return useDb()
    .select({
      userId: userLocations.userId,
      lat: userLocations.lat,
      lng: userLocations.lng,
      updatedAt: userLocations.updatedAt,
      ad: users.ad,
      rol: users.rol,
    })
    .from(userLocations)
    .innerJoin(users, eq(users.id, userLocations.userId))
})
