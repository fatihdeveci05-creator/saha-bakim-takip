# Saha Bakım Takip — Proje Planı

## 1. Özet

Yürüyen merdiven ve asansörlerde saha personelinin yaptığı **bakım, onarım, arıza müdahalesi ve kontrol** işlemlerini uçtan uca takip eden bir sistem. iOS + Android mobil uygulama (saha ekipleri) + web yönetim paneli (yönetici/sorumlu) + ortak backend'den oluşur.

Takip edilecek temel şeyler:
- Personelin günlük iş listesi ve durumu
- Arıza kayıtları ve müdahale/çözüm süreleri (SLA)
- Bakım/onarımda kullanılan malzemeler
- İş öncesi/sonrası fotoğraflar
- Ekipman (asansör/yürüyen merdiven) bazlı geçmiş

## 2. Kullanıcı Rolleri

| Rol | Yetki |
|---|---|
| **Yönetici** | Tüm sahalar, ekipmanlar, ekipler, kullanıcılar; tüm raporlar; iş emri atama/iptal |
| **Sorumlu** | Kendine bağlı saha(lar)/ekip(ler); iş emri atama, onaylama, saha raporu |
| **Arıza Ekibi** | Kendine atanan arıza iş emirleri; müdahale başlat/bitir, malzeme/foto ekle |
| **Bakım Ekibi** | Kendine atanan planlı bakım iş emirleri; checklist doldur, malzeme/foto ekle |
| **Kontrol Ekibi** | Kontrol/denetim iş emirleri; checklist, uygunsuzluk raporlama |

Rol bazlı görünürlük: saha ekipleri sadece kendi işlerini görür, Sorumlu kendi sahasını, Yönetici hepsini.

## 3. Veri Modeli (özet)

- **users** — id, ad, email, telefon, rol, aktif, bağlı ekip
- **teams** — id, ad, tip (arıza/bakım/kontrol), sorumlu_user_id
- **sites** — id, ad, adres, müşteri, konum (lat/lng)
- **equipment** — id, site_id, tip (asansör/yürüyen merdiven), marka, model, seri_no, kurulum_tarihi, qr_kod
- **work_orders** (iş emri) — id, equipment_id, tip (bakım/arıza/kontrol), atanan_user/team, öncelik, durum (bekliyor/devam/tamamlandı/iptal), açılış_zamanı, başlama_zamanı, bitiş_zamanı, **müdahale_süresi**, **çözüm_süresi**, açıklama
- **materials** — id, ad, birim, stok_adedi
- **work_order_materials** — work_order_id, material_id, miktar
- **work_order_photos** — id, work_order_id, url, gps_lat/lng, çekim_zamanı, yükleyen
- **checklists** / **checklist_items** — ekipman tipine göre standart kontrol maddeleri (kontrol ekibi için)
- **work_order_timeline** — durum değişikliği geçmişi, notlar
- **notifications** — atama/SLA uyarısı bildirimleri

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

**Mobil (saha ekipleri):**
- Giriş / rol bazlı ana ekran
- Günlük iş listem (bugün/bekleyen/tamamlanan)
- İş emri detayı (ekipman bilgisi, geçmiş, checklist)
- Müdahale başlat/bitir (süre otomatik başlar)
- Malzeme kullanım girişi
- Fotoğraf ekleme (öncesi/sonrası)
- Arıza bildir (yeni arıza kaydı aç)
- Bildirimler

**Web (Yönetici/Sorumlu):**
- Dashboard (açık iş sayısı, ortalama müdahale süresi, geciken işler)
- Saha/ekipman yönetimi
- Kullanıcı/ekip yönetimi
- İş emri oluşturma/atama
- Raporlar (ekip performansı, SLA, malzeme tüketimi) + export

## 6. Yol Haritası

**Faz 1 — Temel Altyapı**
Auth + roller, saha/ekipman tanımlama, iş emri oluşturma/atama, durum takibi (backend + basit web panel)

**Faz 2 — Saha Operasyonu (Mobil MVP)**
Flutter uygulama: iş listesi, müdahale başlat/bitir, checklist, malzeme girişi, foto ekleme, offline kuyruk

**Faz 3 — Raporlama**
Yönetici dashboard, SLA/performans raporları, export (PDF/Excel)

**Faz 4 — Gelişmiş**
Push bildirimler, QR ile ekipman tarama, harita görünümü, tam offline senkronizasyon

## 7. Açık Kararlar (yarın devam)

- [ ] Uygulama adı
- [ ] Backend'i ayrı Node servis mi yoksa Nuxt Nitro içinde mi tutalım
- [ ] Foto depolama: VPS disk mi, Object Storage mı (başlangıçta VPS disk yeterli)
- [ ] Checklist içerikleri (ekipman tipine göre standart kontrol maddeleri) — sahadan örnek gerekiyor
- [ ] Deploy hedefi: hangi VPS/domain
