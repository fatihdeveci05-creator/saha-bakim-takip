# ABB Kontrol — Proje Planı

## 1. Özet

Yürüyen merdiven ve asansörlerde (**şehir altyapısı — üst geçit vb. lokasyonlar dahil, sadece bina içi değil**) **yüklenici** saha personelinin yaptığı bakım, onarım, arıza müdahalesi ve kontrol işlemlerini kaydettiği; **işveren** tarafının bu kayıtları denetlediği (onay/red) bir sistem. Müşteri/bina yönetimi katmanı yok — sadece bu iki taraf var. iOS + Android mobil uygulama (**hem yüklenici saha ekipleri hem işveren — aynı uygulama, role göre farklı ekranlar**) + web yönetim paneli (işveren, tam raporlama) + ortak backend'den oluşur.

Takip edilecek temel şeyler:
- Alt yüklenicinin günlük iş listesi ve durumu
- Arıza bildirim / müdahale başlama / çözüm saatleri (SLA)
- Bakım/onarımda kullanılan malzemeler
- Foto + o anki GPS konumu (kanıt/doğrulama — QR/NFC yok, kamera çekimiyle eş zamanlı konum alınır)
- **Saha ekiplerinin canlı konumu** — İşveren tarafında haritada, 1 dakikada bir güncellenir
- İşverenin bu kayıtları inceleyip onaylaması/reddetmesi (**denetim akışı**, hem web hem mobilden yapılabilir)
- Ekipman (asansör/yürüyen merdiven) bazlı geçmiş

## 2. Taraflar ve Kullanıcı Rolleri

İki organizasyon var, aynı sistemi paylaşıyorlar ama görevleri zıt: **Yüklenici işi yapıp veriyi girer, İşveren o veriyi denetler.** Sahada tek bir yüklenici organizasyonu var (birden fazla yüklenici şirketi yok) ama onun **çok sayıda personeli** var — her personelin kendi bireysel kullanıcı girişi olur, böylece bir arızayı **hangi personelin çözdüğü** tek tek izlenebilir (paylaşımlı/ekip login'i yok).

**5 rol** (29.08'de netleşti — eski "Sorumlu" rolü **"Yüklenici" olarak yeniden adlandırıldı ve yetkileri genişletildi**):

| Taraf | Rol | Hesap oluşturabilir mi |
|---|---|---|
| İşveren | **İşveren** | Hem saha personeli (Arıza/Bakım/Kontrol Ekibi) hem **Yüklenici hesabı** oluşturabilir — tek yetkili |
| Yüklenici | **Yüklenici** (eski adı: Sorumlu) | Sadece saha personeli (Arıza/Bakım/Kontrol Ekibi) oluşturabilir — **Yüklenici hesabı açamaz** |
| Yüklenici | **Arıza Ekibi** | — |
| Yüklenici | **Bakım Ekibi** | — |
| Yüklenici | **Kontrol Ekibi** | — |

**Günlük görev ataması**: Bir personelin (örn. Ahmet) hesabı açılırken bir temel rolü olur, ama İşveren veya Yüklenici o kişiyi ayrıca **hangi ekip tipinde çalışacağına** (Arıza/Bakım/Kontrol) atar — "Ahmet bugün Arıza Ekibi, Mehmet Kontrol Ekibi, Veli Bakım Ekibi". Bu atama **günlük otomatik sıfırlanmaz, değişiklik yapılana kadar sabit kalır**. İşveren ekranında "o gün görevli personel" listesi bu atamaya göre gösterilir.

### Yetki Matrisi

| Yetki | İşveren | Yüklenici | Arıza Ekibi | Bakım Ekibi | Kontrol Ekibi |
|---|---|---|---|---|---|
| Tüm sahayı görme | ✅ | ✅ | kendi işleri | kendi işleri | denetim rotası |
| Açık arıza kayıtlarını görme | ✅ | ✅ | ✅ | ❌ | ✅ |
| Açık bakım kayıtlarını görme | ✅ | ✅ | ❌ | ✅ | ❌ |
| Arıza/bakım işini **tamamlama** | ✅ (herhangi birini, 29.08 eklendi) | ✅ (herhangi birini) | ✅ (kendi arızaları) | ✅ (kendi bakımları) | ❌ (sadece bildirir) |
| Geçmişe erişim (görüntüleme) | ✅ tam | ✅ tam | ✅ sadece arıza geçmişi | ✅ sadece bakım geçmişi + **ünite künyesi** (bkz. aşağı) | ❌ yok |
| Geçmişi düzenleme | ✅ | ❌ | ❌ | ❌ | ❌ |
| "Onay Bekliyor" kuyruğunu görme | ✅ | ❌ | ❌ | ❌ | ❌ |
| Onay/Red verme | ✅ | ❌ | ❌ | ❌ | ❌ |
| Dökümantasyon/rapor export | ✅ | ✅ | ❌ | ❌ | ❌ |
| Canlı Harita / GPS verisi görme | ✅ | ❌ | ❌ | ❌ | ❌ |
| Saha/ekipman düzenleme | ✅ | ❌ | ❌ | ❌ | ❌ |
| Günlük görev ataması yapma | ✅ | ✅ | ❌ | ❌ | ❌ |
| Arıza kaydı açma (self-servis) | — | — | ✅ | ✅ | ✅ |

**Ünite künyesi** (Bakım Ekibi'ne özel): Arıza Ekibi bir arızayı çözerken "bu, bir sonraki bakımda da tamamlansın" tarzı bir not bırakabilir (örn. iş emri açıklaması/notu). Bakım Ekibi, bir ekipmana gittiğinde o ekipmanın geçmiş arıza notlarını/eksiklerini görebilir — teknik olarak equipment + o ekipmana bağlı work_orders geçmişinin salt-okunur görünümü.

### Kontrol Ekibi — Konum-Tabanlı Denetim Akışı (sadece bu role özel, diğer roller eski basit akışı kullanır)

Kontrol Ekibi'nin işi checklist doldurmak değil, **fiziksel olarak dolaşıp** (üst geçit/ünite ünite) göz muayenesi yapmak. Bu yüzden akışı diğerlerinden tamamen farklı, **konum-tetiklemeli**:

1. Kontrol Ekibi'nin mobil ana ekranı, GPS konumuna göre **en yakın aktif ekipmanı** gösterir.
2. **100 metre yarıçap** içine girildiğinde sistem "buradasınız" olarak algılar, o ekipman için onay ekranı açılır: **"Sorun Yok"** butonu (tek tık, saat/tarih otomatik kaydedilir) — sorun varsa arıza bildirme ekranına geçilir (mevcut self-servis arıza akışı kullanılır).
3. Kontrol Ekibi bir sonraki ekipmana doğru yürüyünce, konum güncellemesiyle ekran **otomatik olarak** o yeni ekipmana geçer.
4. 100m dışındayken onay verilemez (buton pasif) — bu, "gerçekten oradaydı" kanıtı sağlar (fotoğraf+GPS'in Arıza/Bakım'daki karşılığı gibi).

**Açık kalan tasarım detayları** (varsayılanla ilerleyeceğim, itiraz ederseniz değiştiririz):
- Konum güncelleme sıklığı Kontrol Ekibi için diğer rollerden daha sık olmalı (100m'lik alanı kaçırmamak için) — öneri: **15-20 saniyede bir**, diğer roller 1 dk'da bir kalsın.
- Sadece `equipment.aktif = true` olan ekipmanlar bu akışa dahil olsun (yeni alan, veri modeline eklendi).
- "Sorun Yok" kaydı, İşveren onayına düşer mi yoksa direkt kapanır mı — **varsayılan: direkt kapanır** (Kontrol Ekibi zaten Onay Bekliyor'u hiç görmüyor, akış hız odaklı tasarlandı; foto şartı da yok, sadece GPS+zaman kanıt).

**İş emri durum akışı (Arıza/Bakım Ekibi — checklist yok, basit durum makinesi, asansör ve yürüyen merdiven için aynı)**:

Arıza/Bakım Ekibi personeli bir iş emrinde şu durumlardan birini seçer: **Devam Edecek** / **Tamamlandı** / **N/A**.
- **Tamamlandı** seçilebilmesi için **en az 3 fotoğraf eklenmiş olması zorunlu** (uygulama bunu zorlar, foto yoksa "Tamamlandı" seçeneği kilitli kalır).
- Tamamlandı + fotoğraflar girilince durum otomatik olarak **"Onay Bekliyor"**ya geçer — bu personelin seçtiği bir durum değil, sistemin verdiği bir ara durumdur.
- **Onay Bekliyor**daki bir işi sadece **İşveren** rolü onaylayabilir veya reddedebilir (gerekçeli) — **hem mobil uygulamadan hem web panelden**, ikisi de aynı API'yi kullanır. Yüklenici rolü dahil hiç kimse başka onay veremez.
- Onaylanırsa iş emri **"Onaylandı"** ile kapanır.
- Reddedilirse iş emri **"Reddedildi" durumunda, orijinal fotoları/verisiyle olduğu gibi kalır — üzerine yazılmaz** (denetim/tarihçe kaydı olarak korunur). Aynı anda, aynı ekipman için **yeni bir iş emri** açılır (`parent_work_order_id` ile reddedilen işe bağlı), yüklenici tarafına tekrar atanır ve düzeltme baştan, temiz bir kayıt olarak girilir.
- Onay/red geçmişi (kim, ne zaman, ne dedi) ayrıca saklanır.

Rol bazlı görünürlük Bölüm 2'deki yetki matrisinde — özetle: yüklenici tarafı roller kendi kapsamlarındaki işleri/sahayı görür, işveren tüm veriyi görür ama kendisi saha kaydı girmez, sadece denetler.

## 3. Veri Modeli (özet)

- **users** — id, ad, email, telefon, **taraf (işveren/yüklenici)**, rol (işveren/yüklenici/ariza_ekibi/bakim_ekibi/kontrol_ekibi), **gunluk_gorev_tipi** (nullable: ariza/bakim/kontrol — yüklenici tarafı personelinin o günkü/güncel görev ataması, değişene kadar sabit kalır), aktif
- **teams** — id, ad, tip (arıza/bakım/kontrol), sorumlu_user_id (yüklenici tarafında) — *not: günlük görev ataması artık `users.gunluk_gorev_tipi` ile de yönetiliyor, `teams` daha çok organizasyonel gruplama için*
- **sites** — id, ad, adres, konum (lat/lng) — üst geçit gibi şehir altyapısı lokasyonları da olabilir
- **equipment** — id, site_id, tip (asansör/yürüyen merdiven), marka, model, seri_no, kurulum_tarihi, **`aktif`** (boolean, varsayılan true — Kontrol Ekibi'nin konum-tabanlı denetim akışına sadece aktif ekipman dahil olur)
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
- **user_locations** (canlı konum) — user_id (yüklenici tarafı personeli), lat, lng, updated_at — **sadece en güncel konum tutulur** (upsert, geçmiş/iz kaydı MVP'de yok). Mobil uygulama arka planda konum günceller: **Kontrol Ekibi için ~15-20 sn'de bir** (100m yarıçap algılaması için), diğer roller **~1 dakikada bir**.

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

Gerçek senaryo (kullanıcıdan, 28.08): 30 yüklenici saha personeli ama **2 kişi = 1 ekip** (15 ekip); her ekip fotoğraf atmıyor, günde ortalama **~10 cihaz** aktif olarak foto paylaşıyor. 5-10 işveren personeli, ~300 ekipman, cihaz başına günlük ~3 iş emri, iş emri başına ~4 foto (~2MB, mobilde sıkıştırılmış).

- **Asıl darboğaz CPU değil, foto deposu**: 10 cihaz × 3 iş/gün × 4 foto × 2MB ≈ 240MB/gün ≈ 7.2GB/ay ≈ **~86GB/yıl**, 3 yılda ~260GB.
- **Compute**: 2 vCPU / 4GB RAM / ~40-80GB SSD (Hetzner CX22/CPX11 sınıfı) yeterli — günlük 10 aktif cihaz + birkaç işveren kullanıcısı çok hafif bir yük, öngörülenden bile küçük.
- **Foto deposu**: ayrı Hetzner Volume, başlangıç **50-100GB** yeterli, yıllık ~86GB artışa göre 1-2 yılda büyütme kararı verilir (online genişletilebilir).
- **Zorunlu**: Flutter'da yüklemeden önce foto sıkıştırma/resize (max ~1920px, JPEG q~80) — bu, ham kamera çekimlerine göre depolama ihtiyacını 3-5x azaltır.
- Ekipman sayısı (300) hâlâ varsayım — netleşirse iş emri sıklığı tahmini güncellenebilir, ama fotoğraf hacmi asıl olarak aktif cihaz sayısına bağlı, o artık biliniyor.
- Gerçek personel/ekipman sayıları netleşince bu hesap güncellenmeli.

## 5. Ekran Listesi (taslak)

Tek Flutter uygulaması, girişte `taraf`/`rol`'e göre farklı ekran seti gösterilir.

**Mobil — Arıza Ekibi / Bakım Ekibi:**
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

**Mobil — Kontrol Ekibi:**
- Giriş / konum-tabanlı ana ekran (bkz. Bölüm 2, Kontrol Ekibi akışı)
- En yakın/aktif ekipman kartı: "Sorun Yok" butonu, ya da arıza bildir
- 100m dışında: "yaklaşınca aktif olur" bekleme durumu
- Açık arıza kayıtlarını görüntüleme (salt okunur)
- Bildirimler

**Mobil — Yüklenici:**
- Giriş
- Tüm sahalar/ekipmanlar/işler (görüntüleme + tamamlama, düzenleme yok)
- Personel oluşturma + günlük görev ataması (Arıza/Bakım/Kontrol)
- Geçmiş (salt okunur), dökümantasyon export
- Bildirimler
- (Canlı Harita YOK — GPS verisine erişimi yok)

**Mobil — İşveren:**
- Giriş (aynı uygulama, `taraf=işveren` ile farklı ana ekrana yönlenir)
- **Denetim kuyruğu** — "Onay Bekliyor" işler, foto (min 3)+konum+zaman damgalarıyla inceleme, onay/red (gerekçeli)
- **Canlı Harita** — saha ekiplerinin anlık konumu (1 dk'da bir güncellenir)
- Bildirimler (yeni onay bekleyen iş)
- (Tam raporlama/dashboard mobilde yok — o web panelde; mobil, sahadayken/yoldayken hızlı onay + harita için)

**Web (İşveren):**
- Dashboard (açık iş sayısı, onay bekleyen sayısı, ortalama müdahale/çözüm süresi, geciken işler)
- **Denetim kuyruğu** — "Onay Bekliyor" durumundaki işler, foto (min 3)+konum+zaman damgalarıyla inceleme, onay/red
- **Canlı Harita** — saha ekiplerinin anlık konumu (1 dk'da bir güncellenir)
- İş emri detayı + denetim geçmişi (kim ne zaman ne karar verdi)
- Saha/ekipman yönetimi (tanımlama, yüklenici bunu göremez/değiştiremez)
- Kullanıcı yönetimi (İşveren herkesi, Yüklenici sadece saha personelini oluşturabilir) + günlük görev ataması
- Raporlar (personel performansı, SLA uyum oranı, red oranı, malzeme tüketimi) + export — **Yüklenici de bu raporları/export'u görebilir**, düzenleyemez

## 6. Yol Haritası

**Faz 1 — Temel Altyapı** ✅ tamamlandı
Auth + roller, saha/ekipman tanımlama, iş emri oluşturma/atama, durum takibi (backend + web panel)

**Faz 2 — Saha Operasyonu (Mobil MVP)** ✅ tamamlandı
Flutter uygulama: iş listesi, müdahale başlat/bitir, durum seçimi (Devam Edecek/Tamamlandı/N/A) + min. 3 foto zorunluluğu, malzeme girişi, kamera+GPS foto ekleme (≤2MB sıkıştırma), **arka planda ~1 dk'da bir konum gönderimi**. *(Offline kuyruk henüz yok — online-first.)*

**Faz 3 — Denetim + Raporlama + İşveren Mobil** ✅ tamamlandı
İşveren denetim kuyruğu (onay/red akışı + gerekçe + geçmiş) hem web hem mobil, Canlı Harita, dashboard, raporlar + export, push bildirim (FCM) — **canlı deploy'da doğrulandı** (29.08).

**Faz 5 — Rol Genişletmesi + Kontrol Ekibi Konum Akışı** ✅ büyük ölçüde tamamlandı (29.08)
- Rol yeniden yapılandırma: Sorumlu → **Yüklenici** (yetkileri genişletildi: tüm sahayı görme, iş tamamlama, rapor export), yetki matrisi (Bölüm 2) uygulandı
- Hesap oluşturma kısıtları: İşveren herkesi, Yüklenici sadece saha personelini oluşturabilir — tamamlandı
- Günlük görev ataması: ayrı bir alan yerine `users.rol`+`users.takimId` mutable yaklaşımıyla çözüldü (daha basit)
- **Kontrol Ekibi konum-tabanlı denetim akışı**: 100m yarıçap algılama, otomatik ekipman geçişi, "Sorun Yok" hızlı onay, `equipment.aktif` alanı — tamamlandı, VPS'te canlı
- Ünite künyesi (`GET /api/equipment/:id/history`): tüm roller geçmişi görebiliyor — tamamlandı
- **Saha Durumu** (renkli grid+harita, İşveren+Yüklenici görür): web `/saha-durumu` + `/saha-haritasi`, mobil `SahaDurumuBody` (İşveren'de sekme, Yüklenici'de `sorumlu` için AppBar girişi) — tamamlandı, VPS'te canlı (29.08). Grid'de saha adının yanında "Son kontrol: X saat/dakika önce" gösteriliyor, en son kontrol edilen/arızası bildirilen saha en üstte.
- **"Devam Edecek" elden-ele akışı** (29.08): müdahale başlamış ama tamamlanamamış bir iş, atama silinerek tekrar açık havuza döner ki başka bir ekip üyesi devam edebilsin — çözüldü sayılmaz.
- **İşveren mobil parite** (29.08): İşveren artık mobilde de Yüklenici gibi herhangi bir iş emrini tamamlayabiliyor, "Tüm İşler" sekmesiyle sadece denetim kuyruğu değil tüm aktif arıza/bakımı görebiliyor, yeni kullanıcı oluşturabiliyor (mobilde ilk kez).
- **Fotoğraf seri çekim** (29.08): fotoğraf çekimi artık ağ isteği beklemiyor (cihazda tutulur), yükleme durum değiştirirken/bildirim gönderilirken toplu yapılıyor — Kontrol/Arıza/Bakım/Yüklenici/İşveren tüm foto akışlarında.
- **Gerçek cihaz erişimi** (29.08): VPS5 nginx üzerinden zaten herkese açıkmış (`http://45.155.19.196`, HTTP — domain/SSL yok), mobil `ApiConfig.baseUrl` buna güncellendi, release APK gerçek Android telefonda test edildi ve çalışıyor.
- **Arka planda gerçek konum takibi** (29.08 gece): Android'de `flutter_foreground_task` ile kalıcı bildirimli gerçek foreground service (istenen aralıkta güvenilir), iOS'ta geolocator'ın "Her Zaman" izni + arka plan konum modu ile sürekli stream (flutter_foreground_task iOS'ta güvenilir değil, kendi belgesine göre). Emülatörde uçtan uca doğrulandı: uygulama arka plandayken VPS5 DB'de konum gerçekten ilerledi.
- Domain+SSL: kullanıcı kararı — **gerekmiyor**, sade `http://45.155.19.196` ile devam.
- 🔜 Kalan: offline kuyruk, iOS build (Mac gerekiyor, proje zaten hazır — `mobile/ios/`), analiz/trend raporları (red oranı, tekrarlayan arıza — Faz 4'ün konusu, sıradaki odak)

**Faz 4 — Gelişmiş** (Faz 5'ten sonra) — analiz kısmı başladı (30.08)
- ✅ Red oranı trendi (aylık, son 6 ay), müdahale/çözüm süresi trendi, tekrarlayan arıza tespiti (son 90 günde 2+ arıza) — Raporlar sayfasında, VPS'te canlı.
- ✅ Saha/Ekip/Ekipman/Kullanıcı silme (İşveren) — geçmiş verisi olanlar korunuyor, pasife alma öneriliyor.
- 🔜 Kalan: tam offline senkronizasyon, saha/ünite bazlı arıza sıklığı (istenmedi, atlandı)

## 7. Açık Kararlar

- [x] Konum takibi ne zaman aktif olsun: **giriş yapılı alt yüklenici personeli için sürekli** (uygulama açık/kapalı fark etmez, arka planda da — 29.08 eklendi), iş emri durumundan bağımsız
- [ ] KVKK: personel konum takibi kişisel veri sayılır — aydınlatma metni/personel onayı süreci gerekebilir, hukuki/operasyonel bir konu, teknik değil ama unutulmamalı
- [ ] Kontrol Ekibi "Sorun Yok" kaydı İşveren onayına düşsün mü (şu an varsayılan: hayır, direkt kapanır — bkz. Bölüm 2)

**Karara bağlanmış**:
- 5 rol: İşveren, Yüklenici (eski Sorumlu), Arıza Ekibi, Bakım Ekibi, Kontrol Ekibi — tam yetki matrisi Bölüm 2'de
- Günlük görev ataması: personelin hangi ekipte çalıştığı İşveren/Yüklenici tarafından atanır, değişene kadar sabit kalır
- Kontrol Ekibi'nin akışı diğerlerinden tamamen farklı: konum-tabanlı, checklist/foto yok, 100m yarıçap tetiklemeli
- İşveren mobil uygulamaya da kendi hesabıyla girer, onay/red işlemlerini oradan da yapabilir (web ile aynı API, `taraf`/`rol`'e göre farklı ekran)
- Saha ekiplerinin canlı konumu — sadece İşveren tarafında (web+mobil) haritada gösterilir, Yüklenici GPS verisine erişemez
- Uygulama adı: **ABB Kontrol**
- Backend = tek Nuxt 3 Nitro projesi (API+web panel), MySQL, foto depolama şimdilik VPS diskinde (bkz. Bölüm 4)
- Checklist yok (Arıza/Bakım için) — basit durum akışı: Devam Edecek / Tamamlandı (min. 3 foto zorunlu) / N/A → otomatik Onay Bekliyor → sadece İşveren onay/red verir. Kontrol Ekibi ayrı bir akışta (Bölüm 2).
- **Deploy**: `45.155.19.196` (VPS5) — **canlı, gerçek deploy yapıldı** (29.08). PM2 process `abb-kontrol`, `/var/www/abb-kontrol`, app `127.0.0.1:3000`'e bağlı ama nginx (`/etc/nginx/sites-enabled/abb-kontrol`, port 80 `default_server`) üzerinden **herkese açık** (`http://45.155.19.196`, HTTP — domain/SSL yok). Mobil app'in `ApiConfig.baseUrl`'i buraya işaret ediyor. Squid+WireGuard (Sefirox proxy havuzu) aynı VPS'te dokunulmadan duruyor. Detay: hafıza `abb_kontrol_implementation`.
