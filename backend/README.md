# ABB Kontrol — Backend

Nuxt 4 (Nitro) tabanlı tek proje: `server/api/` = API, `app/pages/` = işveren web paneli (bkz. kök `PLAN.md`). Web panel SPA modunda (`ssr:false`), token'lar localStorage'da tutulur, giriş sadece `taraf=isveren` kullanıcılarına açık.

**Web panel sayfaları**: Dashboard, Denetim Kuyruğu (onay/red), İş Emirleri, Canlı Harita (Leaflet, 1 dk'da bir yenilenir), Sahalar, Ekipmanlar, Ekipler, Kullanıcılar, Raporlar (personel performansı, red oranı, malzeme tüketimi + tek tıkla çok sayfalı Excel export — `exceljs` ile üretilir, `xlsx` paketi düzeltmesi olmayan bir güvenlik açığı içerdiği için tercih edilmedi).

`server/middleware/cors.ts`: `/api/*` ve `/uploads/*` için CORS header'ları ekler — native mobil derlemeler için gereksiz ama Flutter uygulamasını web/desktop hedefiyle yerelde test ederken gerekli (bkz. `../mobile/README.md`).

## Yerel geliştirme kurulumu

### 1. MySQL (yerel, portable — kurulum gerektirmez)

Bu makinede organizasyon politikası MSI/servis kurulumunu engellediği için MySQL **portable ZIP** dağıtımı kullanıldı, `C:\mysql84` altında (repo dışında, git'e dahil değil):

- `C:\mysql84\server` — MySQL 8.4.9 ikilileri
- `C:\mysql84\data` — veri dizini
- `C:\mysql84\my.ini` — config (port 3306, sadece 127.0.0.1)

**Başlatmak için:**

```powershell
Start-Process -FilePath "C:\mysql84\server\bin\mysqld.exe" -ArgumentList "--defaults-file=C:\mysql84\my.ini" -WindowStyle Hidden
```

**Durdurmak için:**

```powershell
C:\mysql84\server\bin\mysqladmin.exe -u root -p'RootDev_2026!' shutdown
```

Windows servisi değil (politika engelliyor) — yeniden başlatmada elle çalıştırılması gerekir.

Bağlantı bilgileri (yerel dev, `.env` içinde):
- DB: `abb_kontrol`, app kullanıcı: `abb_app` / `AbbKontrol_Dev_2026!`
- root parolası: `RootDev_2026!` (sadece 127.0.0.1'e bağlı, dışarıya kapalı)

### 2. Bağımlılıklar + migration + seed

```bash
npm install
cp .env.example .env   # zaten dolu bir .env var, gerekirse referans
npm run db:migrate     # şemayı uygula
npm run db:seed        # ilk yönetici kullanıcıyı oluştur (admin@abbkontrol.local / Admin123!)
```

### 3. Dev server

```bash
npm run dev
```

## Diğer script'ler

- `npm run db:generate` — schema.ts değişince yeni migration üretir
- `npm run db:studio` — Drizzle Studio (DB'yi tarayıcıda görüntüle)

## API

- `POST /api/auth/login` — `{ email, password }` → `{ accessToken, refreshToken, user }`
- `POST /api/auth/refresh` — `{ refreshToken }` → `{ accessToken }`
- `GET /api/auth/me` — `Authorization: Bearer <accessToken>` → mevcut kullanıcı
- `GET /api/health` — sağlık kontrolü

**Kullanıcılar** (`yonetici`/`denetci` görebilir, sadece `yonetici` oluşturup/düzenleyebilir):
- `GET /api/users`, `GET /api/users/:id`, `POST /api/users`, `PATCH /api/users/:id`

**Ekipler** (herkes görebilir, sadece `yonetici` oluşturup/düzenleyebilir):
- `GET /api/teams`, `GET /api/teams/:id`, `POST /api/teams`, `PATCH /api/teams/:id`

**Sahalar** (herkes görebilir, sadece `yonetici` oluşturup/düzenleyebilir):
- `GET /api/sites`, `GET /api/sites/:id`, `POST /api/sites`, `PATCH /api/sites/:id`

**Ekipmanlar** (herkes görebilir, sadece `yonetici` oluşturup/düzenleyebilir; `?siteId=` ile filtrelenebilir):
- `GET /api/equipment`, `GET /api/equipment/:id`, `POST /api/equipment`, `PATCH /api/equipment/:id`

**İş emirleri** — durum akışı: `bekliyor` → `devam_edecek` → `tamamlandi` (min. 3 foto zorunlu) → otomatik `onay_bekliyor` → `onaylandi` / `reddedildi` (reddedilirse orijinal değişmez, `parentWorkOrderId` ile yeni bir `bekliyor` kaydı açılır). Görünürlük: işveren (yönetici/denetçi) + alt yüklenici `sorumlu` tümünü görür, diğer alt yüklenici rolleri sadece kendine atananları görür.
- `GET /api/work-orders` (`?durum=` filtreli), `GET /api/work-orders/:id` (foto+review+timeline+malzeme dahil)
- `POST /api/work-orders` — `yonetici`/`sorumlu` istediği alt yüklenici personeline iş atar (`atananUserId` zorunlu); diğer alt yüklenici personeli sadece `tip:"ariza"` ile **kendi adına** self-servis arıza bildirebilir (`atananUserId` görmezden gelinir, otomatik kendisi olur)
- `PATCH /api/work-orders/:id/status` — `{ durum: devam_edecek|tamamlandi|na }`, sadece atanan personel, sadece `bekliyor`/`devam_edecek` durumundayken
- `POST /api/work-orders/:id/photos` — `{ url, gpsLat, gpsLng, cekimZamani, boyutKb? }`, sadece atanan personel, sadece `bekliyor`/`devam_edecek` durumundayken
- `POST /api/work-orders/:id/materials` — `{ materialId, miktar }`, sadece atanan personel, sadece `bekliyor`/`devam_edecek` durumundayken
- `POST /api/work-orders/:id/review` — `{ sonuc: onay|red, gerekce? }` (red için gerekçe zorunlu), sadece `yonetici`, sadece `onay_bekliyor` durumundayken

**Malzeme kataloğu**:
- `GET /api/materials` (herkes), `POST /api/materials` (sadece `yonetici`)

**Canlı konum** (Canlı Harita ekranı):
- `GET /api/locations` — tüm personelin son konumu (`yonetici`/`denetci`)
- `POST /api/locations` — `{ lat, lng }` kendi konumunu günceller (sadece alt yüklenici, upsert)

**Dosya yükleme**:
- `POST /api/uploads` — multipart `file` (jpeg/png/webp) → `{ url }`. Yerel diske (`public/uploads/`) yazar — MVP/dev içindir, üretimde PLAN.md'deki ayrı Hetzner Volume'e taşınmalı.

**Bildirimler** (uygulama içi + push/FCM, bkz. `../mobile/README.md`):
- `GET /api/notifications` — kendi bildirimlerin (en yeni önce, en fazla 100)
- `POST /api/notifications/:id/read`, `POST /api/notifications/read-all`
- `POST /api/users/me/device-token` — `{ token, platform? }`, FCM cihaz token'ını kaydeder/günceller (upsert, token unique)
- Otomatik tetiklenir: yeni arıza self-servis bildirildiğinde → tüm aktif `yonetici`lere; iş ataması yapıldığında → atanan personele; onay/red verildiğinde → atanan personele (`server/utils/notify.ts`) — hem DB kaydı hem (varsa) push gönderimi
- Push gönderimi `server/utils/firebase.ts` (`firebase-admin`) üzerinden olur; **`firebase-service-account.json`** (proje kökünde, `.gitignore`'da — Firebase Console → Project settings → Service accounts → Generate new private key) yoksa gönderim sessizce atlanır, sadece uygulama-içi bildirim çalışır. **Bu proje için (`abb-kontrol`) anahtar eklendi ve doğrulandı** — gerçek FCM'e başarıyla bağlanıyor (sahte bir token'la test edildi: kimlik doğrulama geçti, sadece token'ın kendisi geçersiz olduğu için gönderim başarısız oldu, beklenen sonuç). Gönderim sonucu (`successCount`/`failureCount`) loglanır; artık geçerli olmayan token'lar (`registration-token-not-registered`) otomatik silinir.
