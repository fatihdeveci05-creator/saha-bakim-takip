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

İki organizasyon var, aynı sistemi paylaşıyorlar ama görevleri zıt: **Alt Yüklenici işi yapıp veriyi girer, İşveren o veriyi denetler.**

| Taraf | Rol | Yetki |
|---|---|---|
| İşveren | **Yönetici** | Tüm sahalar/ekipmanlar/kayıtlar; tüm denetim geçmişi; raporlar |
| İşveren | **Denetçi (Sorumlu)** | Kendine bağlı saha(lar); alt yüklenicinin girdiği iş emirlerini inceleme, onay/red (gerekçeli), not düşme |
| Alt Yüklenici | **Sorumlu** | Kendi ekiplerini yönetir, iş atar, kendi sahasının durumunu ve reddedilen işlerini görür |
| Alt Yüklenici | **Arıza Ekibi** | Arıza bildirir, müdahale başlat/bitir, malzeme/foto+konum ekler |
| Alt Yüklenici | **Bakım Ekibi** | Planlı bakım işini yürütür, checklist + malzeme + foto+konum ekler |
| Alt Yüklenici | **Kontrol Ekibi** | Kontrol/inceleme kaydı girer |

**Denetim akışı**: Alt yüklenici bir iş emrini "tamamlandı" yapınca durum **"denetim bekliyor"**ya düşer. İşveren tarafı (Yönetici/Denetçi) fotoları + GPS konumunu + zaman damgalarını inceler → **onaylar** ya da **gerekçeyle reddeder**. Reddedilen iş alt yükleniciye geri döner, düzeltme/ek bilgi istenir. Onay geçmişi (kim, ne zaman, ne dedi) saklanır.

Rol bazlı görünürlük: alt yüklenici sadece kendi işlerini/sahasını görür, işveren tüm alt yüklenici verisini görür ama kendisi saha kaydı girmez — sadece denetler.

## 3. Veri Modeli (özet)

- **users** — id, ad, email, telefon, **taraf (işveren/alt_yüklenici)**, rol, aktif, bağlı ekip
- **teams** — id, ad, tip (arıza/bakım/kontrol), sorumlu_user_id (alt yüklenici tarafında)
- **sites** — id, ad, adres, konum (lat/lng), denetçi_user_id (işveren tarafından sorumlu)
- **equipment** — id, site_id, tip (asansör/yürüyen merdiven), marka, model, seri_no, kurulum_tarihi
- **work_orders** (iş emri) — id, equipment_id, tip (bakım/arıza/kontrol), atanan_user/team, öncelik, durum (bekliyor/devam/tamamlandı/**denetim_bekliyor**/**onaylandı**/**reddedildi**), açıklama, ve zaman damgaları:
  - `occurred_at` — arızanın oluştuğu/fark edildiği zaman (varsa)
  - `reported_at` — arızanın sisteme bildirildiği zaman
  - `response_started_at` — müdahalenin başladığı zaman → **müdahale süresi** = bu − reported_at
  - `resolved_at` — çözüldüğü zaman → **çözüm süresi** = bu − reported_at
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
| Offline senkronizasyon | Local DB (sqflite/drift) + sync queue | Asansör kuyusu/bodrum gibi sinyalsiz alanlarda çalışabilmeli — iş kaydı, foto, malzeme kullanım lokalde tutulur, bağlantı gelince senkronize olur |
| Backend API | Node.js (Nuxt 3 Nitro) + MySQL | Mevcut Hetzner VPS/Mekanik altyapısıyla aynı pattern, deploy deneyimi hazır |
| Web Yönetim Paneli | Nuxt 3 | Yönetici/Sorumlu için masaüstü dashboard, raporlama, atama |
| Foto depolama | VPS disk (ileride Hetzner Object Storage) | Basit başlangıç, büyürse S3-uyumlu depoya taşınabilir |
| Push bildirim | Firebase Cloud Messaging | İş atama, SLA aşımı uyarısı |
| Kimlik doğrulama | JWT + rol bazlı yetkilendirme | Mevcut projelerle tutarlı |

> Not: Bu bir öneridir, sabit değil — istenirse Nuxt+Capacitor (Mekanik projesindeki pattern) ile de tek kod tabanından web+mobil üretilebilir. Kamera/offline/GPS ağırlıklı kullanım nedeniyle Flutter öneriliyor.

## 5. Ekran Listesi (taslak)

**Mobil (Alt Yüklenici saha ekipleri):**
- Giriş / rol bazlı ana ekran
- Günlük iş listem (bugün/bekleyen/tamamlanan/**reddedilen**)
- İş emri detayı (ekipman bilgisi, geçmiş, checklist)
- Müdahale başlat/bitir (süre otomatik başlar)
- Malzeme kullanım girişi
- Fotoğraf ekleme (kamera + otomatik GPS konumu — galeriden seçim yok)
- Arıza bildir (yeni arıza kaydı aç, bildirim zamanı otomatik)
- Reddedilen iş → düzeltme/ek bilgi girip yeniden gönderme
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
- [ ] Backend'i ayrı Node servis mi yoksa Nuxt Nitro içinde mi tutalım
- [ ] Foto depolama: VPS disk mi, Object Storage mı (başlangıçta VPS disk yeterli)
- [ ] Checklist içerikleri (ekipman tipine göre standart kontrol maddeleri) — sahadan örnek gerekiyor
- [ ] Deploy hedefi: hangi VPS/domain
- [ ] Reddedilen iş yeniden gönderildiğinde eski foto/veri korunsun mu, üzerine mi yazılsın (revizyon geçmişi tasarımı)
- [ ] Bir sahada birden fazla alt yüklenici olabilir mi, yoksa saha başına tek alt yüklenici mi
