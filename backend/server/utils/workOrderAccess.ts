import type { AuthTokenPayload } from './jwt'

interface WorkOrderLike {
  atananUserId: number | null
  tip?: string
  durum?: string
}

// İşveren (yönetici/denetçi) her şeyi görür; Yüklenici (sorumlu) tüm saha personelinin
// işlerini görür (ekip yönetimi yetkisi); diğer saha rolleri kendi uzmanlık alanlarındaki
// (bkz. visibleTipsFor) kayıtları görür, sadece kendi işlerine sınırlı değil.
export function canViewAllWorkOrders(payload: AuthTokenPayload) {
  return payload.taraf === 'isveren' || payload.rol === 'sorumlu'
}

// null = kısıtlama yok. Aksi halde bu tip'lerin dışındaki iş emirlerini göremez
// (Arıza Ekibi bakım kayıtlarını göremez, Bakım Ekibi arıza kayıtlarını göremez, vb.
// yetki matrisi — PLAN.md böl. 2).
export function visibleTipsFor(payload: AuthTokenPayload): string[] | null {
  if (payload.rol === 'ariza_ekibi') return ['ariza']
  if (payload.rol === 'bakim_ekibi') return ['bakim']
  if (payload.rol === 'kontrol_ekibi') return ['ariza', 'kontrol']
  return null
}

// Kontrol Ekibi'nin geçmişe (onaylanmış/reddedilmiş, kapanmış kayıtlara) erişimi yok —
// sadece açık arıza kayıtlarını ve kendi kontrol girişlerini görebilir.
export function kontrolEkibiGecmisiGorebilirMi() {
  return false
}

// Atanmamış (atanan_user_id = null) bir iş emrinde, tipine uygun rol işlem
// yapabilir (görüntüleme, durum değiştirme, foto/malzeme ekleme) — ama kimseye
// "kilitlenmez"/otomatik atanmaz, atanan_user_id null kalır (bilinçli atama
// sadece /assign endpoint'i veya Yüklenici/İşveren ile yapılır). Kim çözdüğü
// resolvedByUserId ile ayrıca kayıt altına alınır.
//
// "kontrol" tipi de dahil: Kontrol Ekibi'nin KENDİ GPS-tetiklemeli akışı
// (bkz. /api/kontrol/*) sadece bildirir/anlık kapatır ve buraya girmez, ama
// Yönetici/Sorumlu bir kontrol_ekibi üyesine DOĞRUDAN "kontrol" tipi bir iş
// emri atayabiliyor (bkz. work-orders POST, CAN_ASSIGN_TO_OTHERS) ve bu iş
// normal Müdahale Başlat/Devam Edecek/Tamamlandı akışından geçiyor. "Devam
// Edecek" (elden-ele) sonrası atanan_user_id null'a düşünce, bu satır
// olmadan HİÇBİR kontrol_ekibi üyesi (ilk kişi dahil) o işe bir daha
// erişemiyordu — "Bu iş emri size atanmamış" hatası.
export function canClaimUnassignedWorkOrder(payload: AuthTokenPayload, tip: string) {
  if (tip === 'ariza') return payload.rol === 'ariza_ekibi'
  if (tip === 'bakim') return payload.rol === 'bakim_ekibi'
  if (tip === 'kontrol') return payload.rol === 'kontrol_ekibi'
  return false
}

export function assertCanViewWorkOrder(payload: AuthTokenPayload, workOrder: WorkOrderLike) {
  if (canViewAllWorkOrders(payload)) return
  const kendiIsiMi = workOrder.atananUserId === Number(payload.sub)
  const tips = visibleTipsFor(payload)
  const tipUygunMu = !tips || (workOrder.tip !== undefined && tips.includes(workOrder.tip))

  if (kendiIsiMi && tipUygunMu) return

  // Tip uygunsa (kendi işi olmasa bile) görebilir — ama Kontrol Ekibi için
  // kapanmış (onaylandı/reddedildi) kayıtlar hariç (geçmişe erişimi yok).
  if (tipUygunMu && payload.rol !== 'kontrol_ekibi') return
  if (
    tipUygunMu &&
    payload.rol === 'kontrol_ekibi' &&
    workOrder.durum !== undefined &&
    !['onaylandi', 'reddedildi'].includes(workOrder.durum)
  ) {
    return
  }

  throw createError({ statusCode: 403, statusMessage: 'Bu iş emrini görüntüleme yetkiniz yok' })
}
