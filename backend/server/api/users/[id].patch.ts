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

// "Yüklenici" (kod içinde: sorumlu) sadece bu roller arasında geçiş yapabilir —
// günlük görev ataması ("Ahmet bugün Arıza Ekibi") için.
const yukleniciAtayabilecegiRoller = ['ariza_ekibi', 'bakim_ekibi', 'kontrol_ekibi'] as const

export default defineEventHandler(async (event) => {
  const actor = await requireRole(event, ['yonetici', 'sorumlu'])
  const id = Number(getRouterParam(event, 'id'))
  const body = await readValidatedBody(event, bodySchema.parse)

  const [existing] = await useDb().select({ id: users.id, rol: users.rol }).from(users).where(eq(users.id, id)).limit(1)
  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Kullanıcı bulunamadı' })
  }

  if (actor.rol === 'sorumlu') {
    // Yüklenici sadece halihazırda saha personeli olan hesapların rol/takım
    // atamasını (günlük görev) değiştirebilir — ad/telefon/taraf/aktif düzenleyemez,
    // yönetici/sorumlu hesaplarına dokunamaz.
    const hedefSahaPerseoneliMi = yukleniciAtayabilecegiRoller.includes(
      existing.rol as (typeof yukleniciAtayabilecegiRoller)[number],
    )
    const yeniRolGecerliMi = body.rol === undefined || yukleniciAtayabilecegiRoller.includes(body.rol as any)
    const sadeceGorevAlanlariGonderilmis = Object.keys(body).every((k) => k === 'rol' || k === 'takimId')

    if (!hedefSahaPerseoneliMi || !yeniRolGecerliMi || !sadeceGorevAlanlariGonderilmis) {
      throw createError({
        statusCode: 403,
        statusMessage: 'Sadece saha personelinin günlük görev (rol/ekip) atamasını değiştirebilirsiniz',
      })
    }
  }

  await useDb().update(users).set(body).where(eq(users.id, id))

  const [updated] = await useDb().select(safeUserColumns).from(users).where(eq(users.id, id)).limit(1)
  return updated
})
