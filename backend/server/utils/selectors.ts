import { users } from '../database/schema'

// passwordHash asla API yanıtlarına dahil edilmez
export const safeUserColumns = {
  id: users.id,
  ad: users.ad,
  email: users.email,
  telefon: users.telefon,
  taraf: users.taraf,
  rol: users.rol,
  aktif: users.aktif,
  takimId: users.takimId,
  createdAt: users.createdAt,
  updatedAt: users.updatedAt,
}
