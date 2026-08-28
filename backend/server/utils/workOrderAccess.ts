import type { AuthTokenPayload } from './jwt'

interface WorkOrderLike {
  atananUserId: number | null
}

// İşveren (yönetici/denetçi) her şeyi görür; alt yüklenici Sorumlu tüm alt yüklenici işlerini görür
// (ekip yönetimi yetkisi); diğer alt yüklenici rolleri sadece kendi işini görür.
export function canViewAllWorkOrders(payload: AuthTokenPayload) {
  return payload.taraf === 'isveren' || payload.rol === 'sorumlu'
}

export function assertCanViewWorkOrder(payload: AuthTokenPayload, workOrder: WorkOrderLike) {
  if (canViewAllWorkOrders(payload)) return
  if (workOrder.atananUserId === Number(payload.sub)) return
  throw createError({ statusCode: 403, statusMessage: 'Bu iş emrini görüntüleme yetkiniz yok' })
}
