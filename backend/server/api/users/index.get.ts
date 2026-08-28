import { requireRole } from '../../utils/auth'
import { useDb } from '../../database/client'
import { users } from '../../database/schema'
import { safeUserColumns } from '../../utils/selectors'

export default defineEventHandler(async (event) => {
  await requireRole(event, ['yonetici', 'denetci'])

  return useDb().select(safeUserColumns).from(users)
})
