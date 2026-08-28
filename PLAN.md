# ABB Kontrol — Proje Planı

## 1. Özet

Yürüyen merdiven ve asansörlerde **alt yüklenici** saha personelinin yaptığı bakım, onarım, arıza müdahalesi ve kontrol işlemlerini kaydettiği; **işveren** tarafının bu kayıtları denetlediği (onay/red) bir sistem. Müşteri/bina yönetimi katmanı yok — sadece bu iki taraf var. iOS + Android mobil uygulama (**hem alt yüklenici saha ekipleri hem işveren — aynı uygulama, role göre farklı ekranlar**) + web yönetim paneli (işveren, tam raporlama) + ortak backend'den oluşur.

Takip edilecek temel şeyler:
- Alt yüklenicinin günlük iş listesi ve durumu
- Arıza bildirim / müdahale başlama / çözüm saatleri (SLA)
- Bakım/onarımda kullanılan malzemeler
- Foto + o anki GPS konumu (kanıt/doğrulama — QR/NFC yok, kamera çekimiyle eş zamanlı konum alınır)
- **Saha ekiplerinin canlı konumu** — İşveren tarafında haritada, 1 dakikada bir güncellenir
- İşverenin bu kayıtları inceleyip onaylaması/reddetmesi (**denetim akışı**, hem web hem mobilden yapılabilir)
- Ekipman (asansör/yürüyen merdiven) bazlı geçmiş

## 2. Taraflar ve Kullanıcı Rolleri

İki organizasyon var, aynı sistemi paylaşıyorlar ama görevleri zıt: **Alt Yüklenici işi yapıp veriyi girer, İşveren o veriyi denetler.** Sahada tek bir alt yüklenici organizasyonu var (birden fazla alt yüklenici şirketi yok) ama onun **çok sayıda personeli** var — her personelin kendi bireysel kullanıcı girişi olur, böylece bir arızayı **hangi personelin çözdüğü** tek tek izlenebilir (paylaşımlı/ekip login'i yok).

| Taraf | Rol | Yetki |
|---|---|---|
| İşveren | **Yönetici** | Tüm sahalar/ekipmanlar/kayıtlar; tüm denetim geçmişi; raporlar; **hem web panelden hem mobil uygulamadan** onay/red verebilir, saha ekiplerinin canlı konumunu haritada görür — MVP'de İşveren tarafında **tek rol bu** |
| Alt Yüklenici | **Sorumlu** | Kendi ekiplerini yönetir, iş atar, kendi sahasının durumunu ve reddedilen işlerini görür |
| Alt Yüklenici | **Arıza Ekibi** | Arıza bildirir, müdahale başlat/bitir, malzeme/foto+konum ekler |
| Alt Yüklenici | **Bakım Ekibi** | Planlı bakım işini yürütür, malzeme + foto+konum ekler, durumu günceller |
| Alt Yüklenici | **Kontrol Ekibi** | Kontrol/inceleme kaydı girer |

**İş emri durum akışı (MVP — checklist yok, basit durum makinesi, asansör ve yürüyen merdiven için aynı)**:

Alt yüklenici personeli bir iş emrinde şu durumlardan birini seçer: **Devam Edecek** / **Tamamlandı** / **N/A**.
- **Tamamlandı** seçilebilmesi için **en az 3 fotoğraf eklenmiş olması zorunlu** (uygulama bunu zorlar, foto yoksa "Tamamlandı" seçeneği kilitli kalır).
- Tamamlandı + fotoğraflar girilince durum otomatik olarak **"Onay Bekliyor"**ya geçer — bu personelin seçtiği bir durum değil, sistemin verdiği bir ara durumdur.
- **Onay Bekliyor**daki bir işi sadece **Yönetici** (İşveren tarafı) onaylayabilir veya reddedebilir (gerekçeli) — **hem mobil uygulamadan hem web panelden**, ikisi de aynı API'yi kullanır. MVP'de İşveren tarafında onay yetkisi sadece Yönetici'de — ayrı bir Denetçi rolüne şimdilik gerek yok, ihtiyaç çıkarsa sonra eklenir.
- Onaylanırsa iş emri **"Onaylandı"** ile kapanır.
- Reddedilirse iş emri **"Reddedildi" durumunda, orijinal fotoları/verisiyle olduğu gibi kalır — üzerine yazılmaz** (denetim/tarihçe kaydı olarak korunur). Aynı anda, aynı ekipman için **yeni bir iş emri** açılır (`parent_work_order_id` ile reddedilen işe bağlı), alt yükleniciye tekrar atanır ve düzeltme baştan, temiz bir kayıt olarak girilir.
- Onay/red geçmişi (kim, ne zaman, ne dedi) ayrıca saklanır.

Rol bazlı görünürlük: alt yüklenici sadece kendi işlerini/sahasını görür, işveren tüm alt yüklenici verisini görür ama kendisi saha kaydı girmez — sadece denetler.

## 3. Veri Modeli (özet)

- **users** — id, ad, email, telefon, **taraf (işveren/alt_yüklenici)**, rol, aktif, bağlı ekip
- **teams** — id, ad, tip (arıza/bakım/kontrol), sorumlu_user_id (alt yüklenici tarafında)
- **sites** — id, ad, adres, konum (lat/lng), denetçi_user_id (işveren tarafından sorumlu)
- **equipment** — id, site_id, tip (asansör/yürüyen merdiven), marka, model, seri_no, kurulum_tarihi
- **work_orders** (iş emri) — id, equipment_id, tip (bakım/arıza/kontrol), **atanan_user_id (bireysel personel, ekip değil)**, öncelik, durum (**bekliyor / devam_edecek / tamamlandı / onay_bekliyor / onaylandı / reddedildi / na**), açıklama, **`parent_work_order_id`** (reddedilip yeniden açılan işlerde önceki kayda referans), ve zaman damgaları:
  - **Kural**: durum `tamamlandı`ya geçemez, eğer ilişkili `work_order_photos` sayısı < 3 ise (API validasyonu) — geçince otomatik `onay_bekliyor`ya döner
  - `occurred_at` — arızanın oluştuğu/fark edildiği zaman (varsa)
  - `reported_at` (cihazdan gelen) + `reported_at_server` (sunucunun aldığı an) — ikisi ayrı tutulur, cihaz saati kurcalanmışsa fark edilebilir
  - `response_started_at` — müdahalenin başladığı zaman → **müdahale süresi** = bu − reported_at
  - `resolved_at` — çözüldüğü zaman, **`resolved_by_user_id`** ile birlikte → **çözüm süresi** = bu − reported_at
- **work_order_reviews** (denetim kaydı) — id, work_order_id, reviewer_user_id, sonuç (onay/red), gerekçe, incelenen_zaman — **her denetim turu ayrı satır, geçmiş tutulur**
- **materials** — id, ad, birim, stok_adedi
- **work_order_materials** — work_order_id, material_id, miktar
- **work_order_photos** — id, work_order_id, url, **gps_lat/lng (zorunlu, kamera çekimiyle otomatik alınır)**, çekim_zamanı, yükleyen, boyut_kb (**mobilde yüklemeden önce ≤2MB'a sıkıştırılır**)
- ~~**checklists** / **checklist_items**~~ — **MVP'de yok**, faz sonrası opsiyonel (şimdilik "Tamamlandı" durumu + min. 3 foto yeterli kanıt kabul ediliyor)
- **work_order_timeline** — durum değişikliği geçmişi, notlar
- **notifications** — atama/SLA aşımı/denetim sonucu bildirimleri
- **user_locations** (canlı konum) — user_id (alt yüklenici personeli), lat, lng, updated_at — **sadece en güncel konum tutulur** (upsert, geçmiş/iz kaydı MVP'de yok). Mobil uygulama arka planda **~1 dakikada bir** konumu günceller.

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
| Kimlik doğrulama | JWT (access+refresh), payload'da `taraf`+`rol` | Her endpoint'te taraf/rol bazlı yetki kontrolü — **aynı auth ile hem mobil hem web'e giriş**, `taraf`/`rol`'e göre farklı ekran seti gösterilir |
| Harita | Leaflet + OpenStreetMap (web), `flutter_map` + OSM tile (mobil) | Google Maps API key/maliyet gerekmez, bu ölçekte yeterli |
| Arka plan konum | Flutter `geolocator`, ~1 dk periyotla POST | Android'de pil optimizasyonu arka plan servisini durdurabilir (foreground service bildirimi gerekebilir); iOS'ta "Always" izin + arka plan konum kullanımı App Store review'da gerekçelendirilmeli |

**Denetim bütünlüğü kuralı**: Denetlenmiş (`onaylandı`/`reddedildi`) iş emirleri API'de **UPDATE edilemez** — düzeltme sadece `parent_work_order_id` ile yeni satır olarak eklenir. Hiçbir kayıt hard-delete edilmez (append-only). Bu, verinin sonradan değiştirilemeyeceğini mimari olarak garanti eder.

> Not: Bu bir öneridir, sabit değil — istenirse Nuxt+Capacitor (Mekanik projesindeki pattern) ile de tek kod tabanından web+mobil üretilebilir. Kamera/offline/GPS ağırlıklı kullanım nedeniyle Flutter öneriliyor.

## 4.1 Sunucu Boyutlandırma (tahmini)

Gerçek senaryo (kullanıcıdan, 28.08): 30 alt yüklenici saha personeli ama **2 kişi = 1 ekip** (15 ekip); her ekip fotoğraf atmıyor, günde ortalama **~10 cihaz** aktif olarak foto paylaşıyor. 5-10 işveren personeli, ~300 ekipman, cihaz başına günlük ~3 iş emri, iş emri başına ~4 foto (~2MB, mobilde sıkıştırılmış).

- **Asıl darboğaz CPU değil, foto deposu**: 10 cihaz × 3 iş/gün × 4 foto × 2MB ≈ 240MB/gün ≈ 7.2GB/ay ≈ **~86GB/yıl**, 3 yılda ~260GB.
- **Compute**: 2 vCPU / 4GB RAM / ~40-80GB SSD (Hetzner CX22/CPX11 sınıfı) yeterli — günlük 10 aktif cihaz + birkaç işveren kullanıcısı çok hafif bir yük, öngörülenden bile küçük.
- **Foto deposu**: ayrı Hetzner Volume, başlangıç **50-100GB** yeterli, yıllık ~86GB artışa göre 1-2 yılda büyütme kararı verilir (online genişletilebilir).
- **Zorunlu**: Flutter'da yüklemeden önce foto sıkıştırma/resize (max ~1920px, JPEG q~80) — bu, ham kamera çekimlerine göre depolama ihtiyacını 3-5x azaltır.
- Ekipman sayısı (300) hâlâ varsayım — netleşirse iş emri sıklığı tahmini güncellenebilir, ama fotoğraf hacmi asıl olarak aktif cihaz sayısına bağlı, o artık biliniyor.
- Gerçek personel/ekipman sayıları netleşince bu hesap güncellenmeli.

## 5. Ekran Listesi (taslak)

Tek Flutter uygulaması, girişte `taraf`/`rol`'e göre farklı ekran seti gösterilir.

**Mobil — Alt Yüklenici saha ekipleri:**
- Giriş / rol bazlı ana ekran
- Günlük iş listem (bugün/bekleyen/tamamlanan/**reddedilen**)
- İş emri detayı (ekipman bilgisi, geçmiş) + durum seç: Devam Edecek / Tamamlandı / N/A (**Tamamlandı, en az 3 foto eklenmeden seçilemez**)
- Müdahale başlat/bitir (süre otomatik başlar)
- Malzeme kullanım girişi
- Fotoğraf ekleme (kamera + otomatik GPS konumu — galeriden seçim yok, yüklemeden önce ≤2MB'a sıkıştırılır)
- Arıza bildir (yeni arıza kaydı aç, bildirim zamanı otomatik)
- Reddedilen işlerim listesi → her biri, üzerinden açılan **yeni iş emrine** bağlantı (eski kayıt salt-okunur kalır, düzeltme yeni kayıt olarak girilir)
- Bildirimler (atama, red gerekçesi)
- (Arka planda, kullanıcıya görünmeyen: ~1 dk'da bir konum güncellemesi gönderimi)

**Mobil — İşveren (Yönetici):**
- Giriş (aynı uygulama, `taraf=işveren` ile farklı ana ekrana yönlenir)
- **Denetim kuyruğu** — "Onay Bekliyor" işler, foto (min 3)+konum+zaman damgalarıyla inceleme, onay/red (gerekçeli)
- **Canlı Harita** — saha ekiplerinin anlık konumu (1 dk'da bir güncellenir)
- Bildirimler (yeni onay bekleyen iş)
- (Tam raporlama/dashboard mobilde yok — o web panelde; mobil, sahadayken/yoldayken hızlı onay + harita için)

**Web (İşveren — Yönetici):**
- Dashboard (açık iş sayısı, onay bekleyen sayısı, ortalama müdahale/çözüm süresi, geciken işler)
- **Denetim kuyruğu** — "Onay Bekliyor" durumundaki işler, foto (min 3)+konum+zaman damgalarıyla inceleme, onay/red
- **Canlı Harita** — saha ekiplerinin anlık konumu (1 dk'da bir güncellenir)
- İş emri detayı + denetim geçmişi (kim ne zaman ne karar verdi)
- Saha/ekipman yönetimi (tanımlama, alt yüklenici bunu göremez/değiştiremez)
- Kullanıcı/ekip yönetimi (her iki taraf da işveren tarafından oluşturulur)
- Raporlar (alt yüklenici performansı, SLA uyum oranı, red oranı, malzeme tüketimi) + export

## 6. Yol Haritası

**Faz 1 — Temel Altyapı**
Auth + roller (işveren/alt yüklenici ayrımı), saha/ekipman tanımlama, iş emri oluşturma/atama, durum takibi (backend + basit web panel)

**Faz 2 — Saha Operasyonu (Mobil MVP)**
Flutter uygulama (Alt Yüklenici tarafı): iş listesi, müdahale başlat/bitir, durum seçimi (Devam Edecek/Tamamlandı/N/A) + min. 3 foto zorunluluğu, malzeme girişi, kamera+GPS foto ekleme (≤2MB sıkıştırma), offline kuyruk, **arka planda ~1 dk'da bir konum gönderimi**

**Faz 3 — Denetim + Raporlama + İşveren Mobil**
İşveren denetim kuyruğu (onay/red akışı + gerekçe + geçmiş) **hem web hem mobil**, **Canlı Harita** (saha ekipleri konumu, web+mobil), dashboard, SLA/performans raporları, export (PDF/Excel)

**Faz 4 — Gelişmiş**
Push bildirimler, tam offline senkronizasyon, red oranı/tekrarlayan arıza trend analizleri

## 7. Açık Kararlar

- [ ] Konum takibi ne zaman aktif olsun: uygulama açıkken sürekli mi, yoksa sadece aktif bir iş emri "Devam Edecek" durumundayken mi (pil tüketimi + gizlilik açısından fark yaratır)
- [ ] KVKK: personel konum takibi kişisel veri sayılır — aydınlatma metni/personel onayı süreci gerekebilir, hukuki/operasyonel bir konu, teknik değil ama unutulmamalı

**Karara bağlanmış**:
- İşveren (Yönetici) mobil uygulamaya da kendi hesabıyla girer, onay/red işlemlerini oradan da yapabilir (web ile aynı API, `taraf`/`rol`'e göre farklı ekran)
- Saha ekiplerinin canlı konumu — İşveren tarafında (web+mobil) haritada gösterilir, 1 dakikada bir güncellenir
- Uygulama adı: **ABB Kontrol**
- Backend = tek Nuxt 3 Nitro projesi (API+web panel), MySQL, foto depolama ayrı Hetzner Volume (bkz. Bölüm 4)
- Checklist yok (MVP) — bunun yerine basit durum akışı: Devam Edecek / Tamamlandı (min. 3 foto zorunlu) / N/A → otomatik Onay Bekliyor → sadece Yönetici onay/red verir (bkz. Bölüm 2). Hem asansör hem yürüyen merdiven için aynı akış.
- **Deploy hedefi (geçici)**: `45.155.19.196` (VPS5, SunucumBurada/Başakşehir, Ubuntu 24.04) — Sefirox altyapısında zaten var, 1.9GB RAM / 29GB disk. Üzerinde squid proxy + WireGuard (`10.0.5.2`) Sefirox proxy havuzunun parçası olarak **kalacak, dokunulmayacak**. Eski `whatsapp-siparis-sistemi` kurulumu (pm2 process + nginx site `siparis.sefiroxtv.com` + MariaDB'deki DB) artık gerçek sisteme taşındığı için gereksiz — **gerçek deploy zamanı geldiğinde** kaldırılıp yerine ABB Kontrol kurulacak (şimdiden dokunulmadı, kod henüz yok).
