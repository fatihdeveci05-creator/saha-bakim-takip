# Saha Bakım Takip — Proje Planı

## 1. Özet

Yürüyen merdiven ve asansörlerde **alt yüklenici** saha personelinin yaptığı bakım, onarım, arıza müdahalesi ve kontrol işlemlerini kaydettiği; **işveren** tarafının bu kayıtları denetlediği (onay/red) bir sistem. Müşteri/bina yönetimi katmanı yok — sadece bu iki taraf var. iOS + Android mobil uygulama (alt yüklenici saha ekipleri) + web denetim/yönetim paneli (işveren) + ortak backend'den oluşur.

Takip edilecek temel şeyler:
- Alt yüklenicinin günlük iş listesi ve durumu
- Arıza bildirim / müdahale başlama / çözüm saatleri (SLA)
- Bakım/onarımda kullanılan malzemeler
- Foto + o anki GPS konumu (kanıt/doğrulama — QR/NFC yok, kamera çekimiyle eş zamanlı konum alınır)
- İşverenin bu kayıtları inceleyip onaylaması/reddetmesi (**denetim akışı**)
- Ekipman (asansör/yürüyen merdiven) bazlı geçmiş

## 2. Taraflar ve Kullanıcı Rolleri

İki organizasyon var, aynı sistemi paylaşıyorlar ama görevleri zıt: **Alt Yüklenici işi yapıp veriyi girer, İşveren o veriyi denetler.** Sahada tek bir alt yüklenici organizasyonu var (birden fazla alt yüklenici şirketi yok) ama onun **çok sayıda personeli** var — her personelin kendi bireysel kullanıcı girişi olur, böylece bir arızayı **hangi personelin çözdüğü** tek tek izlenebilir (paylaşımlı/ekip login'i yok).

| Taraf | Rol | Yetki |
|---|---|---|
| İşveren | **Yönetici** | Tüm sahalar/ekipmanlar/kayıtlar; tüm denetim geçmişi; raporlar |
| İşveren | **Denetçi (Sorumlu)** | Kendine bağlı saha(lar); alt yüklenicinin girdiği iş emirlerini inceleme, onay/red (gerekçeli), not düşme |
| Alt Yüklenici | **Sorumlu** | Kendi ekiplerini yönetir, iş atar, kendi sahasının durumunu ve reddedilen işlerini görür |
| Alt Yüklenici | **Arıza Ekibi** | Arıza bildirir, müdahale başlat/bitir, malzeme/foto+konum ekler |
| Alt Yüklenici | **Bakım Ekibi** | Planlı bakım işini yürütür, checklist + malzeme + foto+konum ekler |
| Alt Yüklenici | **Kontrol Ekibi** | Kontrol/inceleme kaydı girer |

**Denetim akışı**: Alt yüklenici bir iş emrini "tamamlandı" yapınca durum **"denetim bekliyor"**ya düşer. İşveren tarafı (Yönetici/Denetçi) fotoları + GPS konumunu + zaman damgalarını inceler → **onaylar** ya da **gerekçeyle reddeder**.
- Onaylanırsa iş emri "onaylandı" ile kapanır.
- Reddedilirse iş emri **"reddedildi" durumunda, orijinal fotoları/verisiyle olduğu gibi kalır — üzerine yazılmaz** (denetim/tarihçe kaydı olarak korunur). Aynı anda, aynı ekipman için **yeni bir iş emri** açılır (`parent_work_order_id` ile reddedilen işe bağlı), alt yükleniciye tekrar atanır ve düzeltme baştan, temiz bir kayıt olarak girilir.
- Onay/red geçmişi (kim, ne zaman, ne dedi) ayrıca saklanır.

Rol bazlı görünürlük: alt yüklenici sadece kendi işlerini/sahasını görür, işveren tüm alt yüklenici verisini görür ama kendisi saha kaydı girmez — sadece denetler.

## 3. Veri Modeli (özet)

- **users** — id, ad, email, telefon, **taraf (işveren/alt_yüklenici)**, rol, aktif, bağlı ekip
- **teams** — id, ad, tip (arıza/bakım/kontrol), sorumlu_user_id (alt yüklenici tarafında)
- **sites** — id, ad, adres, konum (lat/lng), denetçi_user_id (işveren tarafından sorumlu)
- **equipment** — id, site_id, tip (asansör/yürüyen merdiven), marka, model, seri_no, kurulum_tarihi
- **work_orders** (iş emri) — id, equipment_id, tip (bakım/arıza/kontrol), **atanan_user_id (bireysel personel, ekip değil)**, öncelik, durum (bekliyor/devam/tamamlandı/**denetim_bekliyor**/**onaylandı**/**reddedildi**), açıklama, **`parent_work_order_id`** (reddedilip yeniden açılan işlerde önceki kayda referans), ve zaman damgaları:
  - `occurred_at` — arızanın oluştuğu/fark edildiği zaman (varsa)
  - `reported_at` (cihazdan gelen) + `reported_at_server` (sunucunun aldığı an) — ikisi ayrı tutulur, cihaz saati kurcalanmışsa fark edilebilir
  - `response_started_at` — müdahalenin başladığı zaman → **müdahale süresi** = bu − reported_at
  - `resolved_at` — çözüldüğü zaman, **`resolved_by_user_id`** ile birlikte → **çözüm süresi** = bu − reported_at
- **work_order_reviews** (denetim kaydı) — id, work_order_id, reviewer_user_id, sonuç (onay/red), gerekçe, incelenen_zaman — **her denetim turu ayrı satır, geçmiş tutulur**
- **materials** — id, ad, birim, stok_adedi
- **work_order_materials** — work_order_id, material_id, miktar
- **work_order_photos** — id, work_order_id, url, **gps_lat/lng (zorunlu, kamera çekimiyle otomatik alınır)**, çekim_zamanı, yükleyen
- **checklists** / **checklist_items** — ekipman tipine göre standart kontrol maddeleri (kontrol ekibi için)
- **work_order_timeline** — durum değişikliği geçmişi, notlar
- **notifications** — atama/SLA aşımı/denetim sonucu bildirimleri

## 4. Teknoloji Önerisi

| Katman | Seçim | Neden |
|---|---|---|
| Mobil (iOS+Android) | **Flutter** | Tek kod tabanı, kamera + GPS + offline paket ekosistemi saha uygulamaları için olgun; Sefirox iOS'ta da Flutter deneyimi var |
| Offline senkronizasyon | Local DB (sqflite/drift) + sync queue, kayıtlar client-taraflı UUID ile oluşturulur | Asansör kuyusu/bodrum gibi sinyalsiz alanlarda çalışabilmeli; UUID senkronizasyonda çakışma/duplikasyonu önler |
| Backend + Web Paneli | **Tek Nuxt 3 Nitro projesi** (`server/api/` = API, `pages/` = İşveren web paneli) | Mekanik projesinde kanıtlanmış pattern (PM2+nginx+MySQL, tek deploy), aynı altyapı tekrar kullanılır |
| DB | MySQL | Mevcut Hetzner altyapısıyla tutarlı |
| ORM | Drizzle ORM (tip-güvenli) veya doğrudan `mysql2` | Basit, hafif |
| Foto depolama | **Ayrı Hetzner Volume** (`/uploads/{site_id}/{work_order_id}/...`), VPS'in OS diskinden bağımsız | Foto hacmi sürekli büyür (bkz. aşağıdaki hesap) — Volume, VPS'i büyütmeden online genişletilebilir |
| Push bildirim | Firebase Cloud Messaging | Atama, red gerekçesi, SLA aşımı |
| Zamanlanmış görev | node-cron / Nitro scheduled task | SLA aşım kontrolü |
| Kimlik doğrulama | JWT (access+refresh), payload'da `taraf`+`rol` | Her endpoint'te taraf/rol bazlı yetki kontrolü |

**Denetim bütünlüğü kuralı**: Denetlenmiş (`onaylandı`/`reddedildi`) iş emirleri API'de **UPDATE edilemez** — düzeltme sadece `parent_work_order_id` ile yeni satır olarak eklenir. Hiçbir kayıt hard-delete edilmez (append-only). Bu, verinin sonradan değiştirilemeyeceğini mimari olarak garanti eder.

> Not: Bu bir öneridir, sabit değil — istenirse Nuxt+Capacitor (Mekanik projesindeki pattern) ile de tek kod tabanından web+mobil üretilebilir. Kamera/offline/GPS ağırlıklı kullanım nedeniyle Flutter öneriliyor.

## 4.1 Sunucu Boyutlandırma (tahmini)

Örnek senaryo: 30 alt yüklenici saha personeli, 5-10 işveren personeli, 300 ekipman, personel başına günlük 3 iş emri, iş emri başına 4 foto (~2MB, mobilde sıkıştırılmış).

- **Asıl darboğaz CPU değil, foto deposu**: 90 iş/gün × 4 foto × 2MB ≈ 720MB/gün ≈ 21GB/ay ≈ **~260GB/yıl**, 3 yılda ~780GB-1TB.
- **Compute**: 2-3 vCPU / 4GB RAM / ~80GB SSD (Hetzner CPX21 sınıfı) — Nitro API + MySQL için bu ölçekte fazlasıyla yeterli, eşzamanlı kullanıcı sayısı düşük ve trafik hafif JSON ağırlıklı.
- **Foto deposu**: ayrı Hetzner Volume, başlangıç 100-200GB, ihtiyaca göre online büyütülür.
- **Zorunlu**: Flutter'da yüklemeden önce foto sıkıştırma/resize (max ~1920px, JPEG q~80) — bu, ham kamera çekimlerine göre depolama ihtiyacını 3-5x azaltır.
- Gerçek personel/ekipman sayıları netleşince bu hesap güncellenmeli.

## 5. Ekran Listesi (taslak)

**Mobil (Alt Yüklenici saha ekipleri):**
- Giriş / rol bazlı ana ekran
- Günlük iş listem (bugün/bekleyen/tamamlanan/**reddedilen**)
- İş emri detayı (ekipman bilgisi, geçmiş, checklist)
- Müdahale başlat/bitir (süre otomatik başlar)
- Malzeme kullanım girişi
- Fotoğraf ekleme (kamera + otomatik GPS konumu — galeriden seçim yok)
- Arıza bildir (yeni arıza kaydı aç, bildirim zamanı otomatik)
- Reddedilen işlerim listesi → her biri, üzerinden açılan **yeni iş emrine** bağlantı (eski kayıt salt-okunur kalır, düzeltme yeni kayıt olarak girilir)
- Bildirimler (atama, red gerekçesi)

**Web (İşveren — Yönetici/Denetçi):**
- Dashboard (açık iş sayısı, denetim bekleyen sayısı, ortalama müdahale/çözüm süresi, geciken işler)
- **Denetim kuyruğu** — "denetim bekliyor" durumundaki işler, foto+konum+zaman damgalarıyla inceleme, onay/red
- İş emri detayı + denetim geçmişi (kim ne zaman ne karar verdi)
- Saha/ekipman yönetimi (tanımlama, alt yüklenici bunu göremez/değiştiremez)
- Kullanıcı/ekip yönetimi (her iki taraf da işveren tarafından oluşturulur)
- Raporlar (alt yüklenici performansı, SLA uyum oranı, red oranı, malzeme tüketimi) + export

## 6. Yol Haritası

**Faz 1 — Temel Altyapı**
Auth + roller (işveren/alt yüklenici ayrımı), saha/ekipman tanımlama, iş emri oluşturma/atama, durum takibi (backend + basit web panel)

**Faz 2 — Saha Operasyonu (Mobil MVP)**
Flutter uygulama: iş listesi, müdahale başlat/bitir, checklist, malzeme girişi, kamera+GPS foto ekleme, offline kuyruk

**Faz 3 — Denetim + Raporlama**
İşveren denetim kuyruğu (onay/red akışı + gerekçe + geçmiş), dashboard, SLA/performans raporları, export (PDF/Excel)

**Faz 4 — Gelişmiş**
Push bildirimler, harita görünümü (saha/ekip konumları), tam offline senkronizasyon, red oranı/tekrarlayan arıza trend analizleri

## 7. Açık Kararlar (yarın devam)

- [ ] Uygulama adı
- [ ] Checklist içerikleri (ekipman tipine göre standart kontrol maddeleri) — kullanıcı verecek
- [ ] Deploy hedefi: hangi VPS/domain — backend mimarisi netleştiği için şimdi konuşulabilir (bkz. Bölüm 4)

**Karara bağlanmış**: Backend = tek Nuxt 3 Nitro projesi (API+web panel), MySQL, foto depolama VPS disk ile başlar (bkz. Bölüm 4).
