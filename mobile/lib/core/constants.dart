class ApiConfig {
  /// VPS5'teki canlı backend (nginx :80 üzerinden herkese açık, HTTP — henüz
  /// domain/SSL yok). Gerçek cihazda (WiFi/mobil veri farketmez) böyle
  /// çalışır. Yerel geliştirme yaparken (dev sunucusu değişikliklerini
  /// anında görmek için) geçici olarak şunlardan biriyle değiştirin:
  /// - Android emulator + `adb reverse tcp:3000 tcp:3000`: http://localhost:3000
  /// - Android emulator (reverse olmadan): http://10.0.2.2:3000
  /// - Fiziksel cihaz + aynı WiFi'deki dev makinesi: http://192.168.x.x:3000
  static const String baseUrl = 'http://45.155.19.196';

  /// Alt yüklenici saha personeli için arka plan konum gönderim periyodu.
  static const Duration locationInterval = Duration(minutes: 1);

  /// Kontrol Ekibi için daha sık — 100m yarıçaplı ekipman algılamasını kaçırmamak için.
  static const Duration kontrolLocationInterval = Duration(seconds: 15);
}
