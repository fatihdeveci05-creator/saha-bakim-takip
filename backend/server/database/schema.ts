import {
  mysqlTable,
  int,
  varchar,
  text,
  boolean,
  timestamp,
  decimal,
  mysqlEnum,
  primaryKey,
} from 'drizzle-orm/mysql-core'

// --- Enums (ortak sözlükler) -----------------------------------------

export const tarafEnum = ['isveren', 'alt_yuklenici'] as const
export const rolEnum = [
  'yonetici',
  'denetci',
  'sorumlu',
  'ariza_ekibi',
  'bakim_ekibi',
  'kontrol_ekibi',
] as const
export const ekipTipEnum = ['ariza', 'bakim', 'kontrol'] as const
export const ekipmanTipEnum = ['asansor', 'yuruyen_merdiven'] as const
export const isEmriTipEnum = ['bakim', 'ariza', 'kontrol'] as const
export const isEmriDurumEnum = [
  'bekliyor',
  'devam_edecek',
  'tamamlandi',
  'onay_bekliyor',
  'onaylandi',
  'reddedildi',
  'na',
] as const
export const denetimSonucEnum = ['onay', 'red'] as const

// --- Tablolar (PLAN.md bölüm 3) ----------------------------------------

export const users = mysqlTable('users', {
  id: int('id').autoincrement().primaryKey(),
  ad: varchar('ad', { length: 255 }).notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  telefon: varchar('telefon', { length: 30 }),
  passwordHash: varchar('password_hash', { length: 255 }).notNull(),
  taraf: mysqlEnum('taraf', tarafEnum).notNull(),
  rol: mysqlEnum('rol', rolEnum).notNull(),
  aktif: boolean('aktif').notNull().default(true),
  takimId: int('takim_id'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().onUpdateNow(),
})

export const teams = mysqlTable('teams', {
  id: int('id').autoincrement().primaryKey(),
  ad: varchar('ad', { length: 255 }).notNull(),
  tip: mysqlEnum('tip', ekipTipEnum).notNull(),
  sorumluUserId: int('sorumlu_user_id'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

export const sites = mysqlTable('sites', {
  id: int('id').autoincrement().primaryKey(),
  ad: varchar('ad', { length: 255 }).notNull(),
  adres: text('adres'),
  lat: decimal('lat', { precision: 10, scale: 7 }),
  lng: decimal('lng', { precision: 10, scale: 7 }),
  denetciUserId: int('denetci_user_id'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

export const equipment = mysqlTable('equipment', {
  id: int('id').autoincrement().primaryKey(),
  siteId: int('site_id').notNull(),
  tip: mysqlEnum('tip', ekipmanTipEnum).notNull(),
  marka: varchar('marka', { length: 255 }),
  model: varchar('model', { length: 255 }),
  seriNo: varchar('seri_no', { length: 100 }),
  kurulumTarihi: timestamp('kurulum_tarihi'),
  // Kontrol Ekibi'nin konum-tabanlı denetim akışına sadece aktif ekipman dahil olur.
  aktif: boolean('aktif').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

export const workOrders = mysqlTable('work_orders', {
  id: int('id').autoincrement().primaryKey(),
  equipmentId: int('equipment_id').notNull(),
  tip: mysqlEnum('tip', isEmriTipEnum).notNull(),
  atananUserId: int('atanan_user_id'),
  oncelik: varchar('oncelik', { length: 20 }),
  durum: mysqlEnum('durum', isEmriDurumEnum).notNull().default('bekliyor'),
  aciklama: text('aciklama'),
  parentWorkOrderId: int('parent_work_order_id'),
  occurredAt: timestamp('occurred_at'),
  reportedAt: timestamp('reported_at'),
  reportedAtServer: timestamp('reported_at_server'),
  responseStartedAt: timestamp('response_started_at'),
  resolvedAt: timestamp('resolved_at'),
  resolvedByUserId: int('resolved_by_user_id'),
  // Kontrol Ekibi'nin konum-tabanlı "Sorun Yok" onayı için — sadece tip='kontrol'da dolu.
  // Fotoğraf şartı yok, kanıt bu GPS koordinatı + zaman damgası.
  checkGpsLat: decimal('check_gps_lat', { precision: 10, scale: 7 }),
  checkGpsLng: decimal('check_gps_lng', { precision: 10, scale: 7 }),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().onUpdateNow(),
})

export const workOrderReviews = mysqlTable('work_order_reviews', {
  id: int('id').autoincrement().primaryKey(),
  workOrderId: int('work_order_id').notNull(),
  reviewerUserId: int('reviewer_user_id').notNull(),
  sonuc: mysqlEnum('sonuc', denetimSonucEnum).notNull(),
  gerekce: text('gerekce'),
  incelenenZaman: timestamp('incelenen_zaman').notNull().defaultNow(),
})

export const materials = mysqlTable('materials', {
  id: int('id').autoincrement().primaryKey(),
  ad: varchar('ad', { length: 255 }).notNull(),
  birim: varchar('birim', { length: 50 }),
  stokAdedi: int('stok_adedi').notNull().default(0),
})

export const workOrderMaterials = mysqlTable(
  'work_order_materials',
  {
    workOrderId: int('work_order_id').notNull(),
    materialId: int('material_id').notNull(),
    miktar: decimal('miktar', { precision: 10, scale: 2 }).notNull(),
  },
  (t) => [primaryKey({ columns: [t.workOrderId, t.materialId] })],
)

export const workOrderPhotos = mysqlTable('work_order_photos', {
  id: int('id').autoincrement().primaryKey(),
  workOrderId: int('work_order_id').notNull(),
  url: varchar('url', { length: 500 }).notNull(),
  gpsLat: decimal('gps_lat', { precision: 10, scale: 7 }).notNull(),
  gpsLng: decimal('gps_lng', { precision: 10, scale: 7 }).notNull(),
  cekimZamani: timestamp('cekim_zamani').notNull(),
  yukleyenUserId: int('yukleyen_user_id').notNull(),
  boyutKb: int('boyut_kb'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

export const workOrderTimeline = mysqlTable('work_order_timeline', {
  id: int('id').autoincrement().primaryKey(),
  workOrderId: int('work_order_id').notNull(),
  durum: mysqlEnum('durum', isEmriDurumEnum).notNull(),
  not: text('not'),
  createdByUserId: int('created_by_user_id'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

export const notifications = mysqlTable('notifications', {
  id: int('id').autoincrement().primaryKey(),
  userId: int('user_id').notNull(),
  tip: varchar('tip', { length: 50 }).notNull(),
  mesaj: text('mesaj').notNull(),
  relatedWorkOrderId: int('related_work_order_id'),
  okundu: boolean('okundu').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

// Push bildirim (FCM) için cihaz token'ları — bir kullanıcının birden fazla cihazı olabilir.
export const deviceTokens = mysqlTable('device_tokens', {
  id: int('id').autoincrement().primaryKey(),
  userId: int('user_id').notNull(),
  token: varchar('token', { length: 255 }).notNull().unique(),
  platform: varchar('platform', { length: 20 }),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

// Sadece en güncel konum tutulur (upsert) — iz/geçmiş kaydı MVP'de yok
export const userLocations = mysqlTable('user_locations', {
  userId: int('user_id').primaryKey(),
  lat: decimal('lat', { precision: 10, scale: 7 }).notNull(),
  lng: decimal('lng', { precision: 10, scale: 7 }).notNull(),
  updatedAt: timestamp('updated_at').notNull().defaultNow().onUpdateNow(),
})
