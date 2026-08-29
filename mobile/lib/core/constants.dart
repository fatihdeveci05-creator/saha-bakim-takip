class ApiConfig {
  /// Hedefe göre değiştirin:
  /// - Chrome/Web, iOS simulator, Windows desktop: http://localhost:3000
  /// - Android emulator: http://10.0.2.2:3000 (dev makinesinin localhost'una karşılık gelir)
  /// - Fiziksel cihaz: aynı Wi-Fi ağındaki makinenin LAN IP'si (örn. http://192.168.1.23:3000)
  static const String baseUrl = 'http://localhost:3000';

  /// Alt yüklenici saha personeli için arka plan konum gönderim periyodu.
  static const Duration locationInterval = Duration(minutes: 1);

  /// Kontrol Ekibi için daha sık — 100m yarıçaplı ekipman algılamasını kaçırmamak için.
  static const Duration kontrolLocationInterval = Duration(seconds: 15);
}
