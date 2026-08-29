export type Durum =
  | 'bekliyor'
  | 'devam_edecek'
  | 'tamamlandi'
  | 'onay_bekliyor'
  | 'onaylandi'
  | 'reddedildi'
  | 'na'

export interface Site {
  id: number
  ad: string
  adres: string | null
  lat: string | null
  lng: string | null
  denetciUserId: number | null
  createdAt: string
}

export interface Equipment {
  id: number
  siteId: number
  tip: 'asansor' | 'yuruyen_merdiven'
  marka: string | null
  model: string | null
  seriNo: string | null
  kurulumTarihi: string | null
  createdAt: string
}

export interface Team {
  id: number
  ad: string
  tip: 'ariza' | 'bakim' | 'kontrol'
  sorumluUserId: number | null
  createdAt: string
}

export interface AppUser {
  id: number
  ad: string
  email: string
  telefon: string | null
  taraf: 'isveren' | 'alt_yuklenici'
  rol: string
  aktif: boolean
  takimId: number | null
  createdAt: string
  updatedAt: string
}

export interface WorkOrderPhoto {
  id: number
  workOrderId: number
  url: string
  gpsLat: string
  gpsLng: string
  cekimZamani: string
  yukleyenUserId: number
  boyutKb: number | null
  createdAt: string
}

export interface WorkOrderReview {
  id: number
  workOrderId: number
  reviewerUserId: number
  sonuc: 'onay' | 'red'
  gerekce: string | null
  incelenenZaman: string
}

export interface WorkOrderTimelineEntry {
  id: number
  workOrderId: number
  durum: Durum
  not: string | null
  createdByUserId: number | null
  createdAt: string
}

export interface WorkOrder {
  id: number
  equipmentId: number
  tip: 'bakim' | 'ariza' | 'kontrol'
  atananUserId: number | null
  oncelik: string | null
  durum: Durum
  aciklama: string | null
  parentWorkOrderId: number | null
  occurredAt: string | null
  reportedAt: string | null
  reportedAtServer: string | null
  responseStartedAt: string | null
  resolvedAt: string | null
  resolvedByUserId: number | null
  atananAd: string | null
  resolvedByAd: string | null
  createdAt: string
  updatedAt: string
}

export interface WorkOrderDetail extends WorkOrder {
  photos: WorkOrderPhoto[]
  reviews: WorkOrderReview[]
  timeline: WorkOrderTimelineEntry[]
}

export interface UserLocation {
  userId: number
  lat: string
  lng: string
  updatedAt: string
  ad: string
  rol: string
}

export interface PersonelPerformans {
  userId: number
  ad: string
  atananSayisi: number
  onaylananSayisi: number
  reddedilenSayisi: number
  ortMudahaleSaat: number | null
  ortCozumSaat: number | null
}

export interface RedOraniByUser {
  userId: number
  ad: string
  toplamDenetim: number
  red: number
  oran: number | null
}

export interface MalzemeTuketimi {
  materialId: number
  ad: string
  birim: string | null
  toplamMiktar: number
}

export interface ReportsData {
  personelPerformans: PersonelPerformans[]
  redOrani: {
    toplamDenetim: number
    red: number
    onay: number
    oran: number | null
    byUser: RedOraniByUser[]
  }
  malzemeTuketimi: MalzemeTuketimi[]
}

export const DURUM_LABELS: Record<Durum, string> = {
  bekliyor: 'Bekliyor',
  devam_edecek: 'Devam Edecek',
  tamamlandi: 'Tamamlandı',
  onay_bekliyor: 'Onay Bekliyor',
  onaylandi: 'Onaylandı',
  reddedildi: 'Reddedildi',
  na: 'N/A',
}
