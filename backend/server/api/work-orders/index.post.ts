import { eq } from 'drizzle-orm'
import { z } from 'zod'
import { requireAuth } from '../../utils/auth'
import { useDb } from '../../database/client'
import { workOrders, workOrderTimeline, equipment, sites, users, isEmriTipEnum } from '../../database/schema'
import { notifyUser, notifyYoneticiler } from '../../utils/notify'
import { getUserTeamId } from '../../utils/teamScope'

const TIP_LABELS: Record<string, string> = { bakim: 'Bakım', ariza: 'Arıza', kontrol: 'Kontrol' }

const bodySchema = z.object({
  equipmentId: z.number().int(),
  tip: z.enum(isEmriTipEnum),
  atananUserId: z.number().int().optional(),
  oncelik: z.string().max(20).optional(),
  aciklama: z.string().optional(),
  occurredAt: z.string().datetime().optional(),
})

// Yönetici/sorumlu istediği personele iş atayabilir (bakım/kontrol planlaması) —
// personel seçimi zorunlu değil, atanmamış bırakılıp sonradan atanabilir
// (bkz. PATCH /api/work-orders/:id/assign). Diğer alt yüklenici personeli
// sadece kendi adına arıza bildirebilir (self-servis).
const CAN_ASSIGN_TO_OTHERS = ['yonetici', 'sorumlu']

export default defineEventHandler(async (event) => {
  const payload = await requireAuth(event)
  const body = await readValidatedBody(event, bodySchema.parse)

  const canAssignToOthers = CAN_ASSIGN_TO_OTHERS.includes(payload.rol)
  let atananUserId: number | undefined

  if (canAssignToOthers) {
    atananUserId = body.atananUserId
  } else if (payload.taraf === 'alt_yuklenici') {
    if (body.tip !== 'ariza') {
      throw createError({ statusCode: 403, statusMessage: 'Sadece arıza bildirebilirsiniz' })
    }
    // Arıza Ekibi kendi bildirdiği arızayı genelde kendi çözer, o yüzden
    // kendine atanır. Kontrol Ekibi (ve diğer roller) sadece bildirir,
    // müdahale etmez — atanmamış bırakılır ki herhangi bir Arıza Ekibi
    // üyesi alabilsin (bkz. workOrderAccess.canClaimUnassignedWorkOrder).
    atananUserId = payload.rol === 'ariza_ekibi' ? Number(payload.sub) : undefined
  } else {
    throw createError({ statusCode: 403, statusMessage: 'Bu işlem için yetkiniz yok' })
  }

  const db = useDb()

  const [eq1] = await db
    .select({ id: equipment.id, siteAd: sites.ad })
    .from(equipment)
    .innerJoin(sites, eq(sites.id, equipment.siteId))
    .where(eq(equipment.id, body.equipmentId))
    .limit(1)
  if (!eq1) {
    throw createError({ statusCode: 400, statusMessage: 'Ekipman bulunamadı' })
  }

  if (atananUserId) {
    const [assignee] = await db
      .select({ id: users.id, taraf: users.taraf, aktif: users.aktif, takimId: users.takimId })
      .from(users)
      .where(eq(users.id, atananUserId))
      .limit(1)
    if (!assignee || assignee.taraf !== 'alt_yuklenici' || !assignee.aktif) {
      throw createError({ statusCode: 400, statusMessage: 'Atanan kullanıcı geçersiz (aktif alt yüklenici personeli olmalı)' })
    }
    if (payload.rol === 'sorumlu') {
      const ownTeamId = await getUserTeamId(Number(payload.sub))
      if (!ownTeamId || assignee.takimId !== ownTeamId) {
        throw createError({ statusCode: 403, statusMessage: 'Sadece kendi ekibinizdeki personele atama yapabilirsiniz' })
      }
    }
  }

  const now = new Date()
  const [result] = await db.insert(workOrders).values({
    equipmentId: body.equipmentId,
    tip: body.tip,
    atananUserId,
    oncelik: body.oncelik,
    aciklama: body.aciklama,
    durum: 'bekliyor',
    occurredAt: body.occurredAt ? new Date(body.occurredAt) : undefined,
    reportedAt: body.occurredAt ? new Date(body.occurredAt) : now,
    reportedAtServer: now,
  })

  await db.insert(workOrderTimeline).values({
    workOrderId: result.insertId,
    durum: 'bekliyor',
    createdByUserId: Number(payload.sub),
  })

  if (canAssignToOthers) {
    if (atananUserId) {
      await notifyUser(
        atananUserId,
        'atama',
        `Size yeni bir iş atandı: ${TIP_LABELS[body.tip]} — ${eq1.siteAd}`,
        result.insertId,
      )
    }
  } else {
    await notifyYoneticiler('yeni_ariza', `Yeni arıza bildirildi: ${eq1.siteAd}`, result.insertId)
  }

  const [created] = await db.select().from(workOrders).where(eq(workOrders.id, result.insertId)).limit(1)
  setResponseStatus(event, 201)
  return created
})
