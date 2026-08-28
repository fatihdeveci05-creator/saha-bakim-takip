# ABB Kontrol — Mobil

Flutter uygulaması, tek kod tabanı — `taraf`'a göre farklı ekran seti:

- **Alt yüklenici saha ekipleri** (Faz 2): giriş, iş listem (bugün/bekleyen/tamamlanan/reddedilen,
  her sekmede kayıt sayısı), iş emri detayı (durum akışı, kamera+GPS foto, malzeme girişi, zaman
  çizelgesi), arıza bildir, ~1 dk'da bir konum gönderimi.
- **Sorumlu** (alt yüklenici ekip lideri): yukarıdakilere ek olarak **İş Ata** ekranı — ekibindeki
  birine bakım/kontrol/arıza işi atayabilir (saha/ekipman/personel/öncelik seçimi).
- **İşveren** (Faz 3): denetim kuyruğu (onay/red, aynı detay ekranı üzerinden), canlı harita
  (flutter_map + OSM, saha ekiplerinin konumu).
- **Bildirimler** (Faz 4, uygulama içi): her iki tarafta da AppBar'da zil ikonu + okunmamış sayısı
  rozeti; 30 sn'de bir ve uygulama arka plandan öne dönünce otomatik yenilenir. Yeni arıza
  bildirildiğinde tüm yöneticilere, iş ataması yapıldığında ve onay/red verildiğinde ilgili
  personele bildirim düşer; tıklayınca ilgili iş emrine gider.

Backend: `../backend` (bkz. o klasördeki README, API sözleşmesi orada).

## Kurulum

```bash
flutter pub get
```

`lib/core/constants.dart` içindeki `ApiConfig.baseUrl`'i ortamınıza göre ayarlayın:
- Chrome/Web, iOS simulator, Windows desktop: `http://localhost:3000` (varsayılan)
- Android emulator: `http://10.0.2.2:3000` (dev makinesinin localhost'una karşılık gelir)
- Fiziksel cihaz: dev makinesinin aynı Wi-Fi ağındaki LAN IP'si

Backend'in çalışıyor ve migration+seed'in uygulanmış olması gerekir (`../backend/README.md`).
Backend'de `server/middleware/cors.ts` sadece web/desktop hedefiyle yerelde test ederken
gerekli (native mobil derlemelerde CORS diye bir şey yok).

## Çalıştırma

```bash
flutter run
```

Bu makinede Android SDK/emülatör kurulu değil. Kod `flutter analyze`/`flutter test` ile
doğrulandı; ayrıca **Chrome hedefiyle gerçekten çalıştırılıp uçtan uca test edildi**
(`flutter build web` + statik sunucu + Playwright): giriş, iş listesi, durum güncelleme,
foto+malzeme ekleme, arka plan konum gönderimi, N/A akışı (açıklama + zaman çizelgesinde
görünmesi), bildirimler (rozet, okundu işaretleme, ilgili iş emrine yönlendirme), işveren
tarafında denetim kuyruğu + canlı harita + onay/red akışı — hepsi gerçek backend'e karşı
doğrulandı. Android/iOS'ta kamera ve konum davranışı farklı olacaktır (gerçek cihaz/emülatör
gerektirir).

## Kapsam / MVP sınırlamaları

PLAN.md'nin kapsamındaki şu parçalar **henüz yok**:

- **Offline kuyruk yok** — uygulama online-first çalışır, ağ yoksa istekler başarısız olur.
  PLAN.md'de öngörülen sqflite/drift tabanlı offline senkron kuyruğu ayrı bir iş.
- **Arka plan konum sadece uygulama açıkken çalışır** — uygulama kapatılınca/arka plana
  atılınca durur (bkz. `lib/services/location_service.dart` içindeki not). Gerçek arka
  plan takibi için Android'de foreground service + bildirim, iOS'ta "Always" izin gerekir.
## Push bildirim (FCM)

Firebase Android (`google-services.json`) ve iOS (`GoogleService-Info.plist`) yapılandırma
dosyaları projeye eklendi (`.gitignore`'da, commit edilmez), `firebase_core`+`firebase_messaging`
entegre edildi. Web hedefinde tamamen atlanır (`kIsWeb` guard'ı, ayrı bir web config gerektirir
ve kapsam dışı bırakıldı) — bu sayede Chrome'daki test akışımız etkilenmedi.

- Girişte izin istenir, FCM token alınıp `POST /api/users/me/device-token` ile backend'e kaydedilir
- Ön planda gelen mesaj → sadece `NotificationService.refresh()` tetiklenir (OS bildirimi göstermez, zaten uygulama açık)
- Arka planda/kapalıyken → OS bildirimi otomatik gösterilir (FCM'in "notification" payload'ı sayesinde, ek kod gerekmez), tıklanınca ilgili iş emrine yönlendirir
- Backend'de gönderim: `server/utils/firebase.ts` + `firebase-admin` — `firebase-service-account.json` (backend kökünde, `.gitignore`'da) **henüz eklenmedi**, eklenene kadar gönderim sessizce no-op olur (uygulama çökmez, sadece uygulama-içi bildirim çalışır)
- **Gerçek cihazda/emülatörde denenmedi** — bu makinede Android SDK yok. Kod `flutter analyze` ile doğrulandı ve web build'in bundan etkilenmediği test edildi, ama push'un fiilen telefona düşmesi gerçek bir build+cihaz gerektirir

## Kapsam / MVP sınırlamaları

PLAN.md'nin kapsamındaki şu parça **henüz yok**:

- **Offline kuyruk yok** — uygulama online-first çalışır, ağ yoksa istekler başarısız olur.
  PLAN.md'de öngörülen sqflite/drift tabanlı offline senkron kuyruğu ayrı bir iş.
- **Arka plan konum sadece uygulama açıkken çalışır** — uygulama kapatılınca/arka plana
  atılınca durur (bkz. `lib/services/location_service.dart` içindeki not). Gerçek arka
  plan takibi için Android'de foreground service + bildirim, iOS'ta "Always" izin gerekir.

## Mimari

- `core/auth_service.dart` — login/refresh/logout, token'lar `flutter_secure_storage`'da
- `core/api_client.dart` — Dio + 401'de otomatik refresh interceptor'ı
- `core/navigation.dart` — global `navigatorKey`, push bildirim tıklamasından ekran açmak için
- `services/push_service.dart` — FCM izin/token kaydı, ön plan/arka plan mesaj yönetimi
- `models/` — backend API şemasına karşılık gelen Dart modelleri
- `screens/home_screen.dart` — alt yüklenici iş listem (tab'lı, sayaçlı, arka plandan dönünce yenilenir)
- `screens/work_order_detail_screen.dart` — hem alt yüklenici (durum/foto/malzeme/N-A) hem
  işveren (onay/red) için ortak detay ekranı; hangi kontrollerin göründüğü role/duruma göre belirlenir
- `screens/report_ariza_screen.dart` — self-servis arıza bildirimi
- `screens/assign_work_order_screen.dart` — `sorumlu` için iş atama (bakım/kontrol/arıza)
- `screens/employer_home_screen.dart` — işveren: denetim kuyruğu (arka plandan dönünce yenilenir) + canlı harita
- `screens/notifications_screen.dart` — bildirim listesi + `NotificationBellButton` (AppBar rozeti)
- `services/location_service.dart` — periyodik konum gönderimi
- `services/notification_service.dart` — periyodik bildirim polling'i + okunmamış sayacı
