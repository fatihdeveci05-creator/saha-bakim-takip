import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/constants.dart';

/// Arka planda (uygulama kapalı/arka plandayken de) periyodik konum gönderimi.
/// Platform davranışı FARKLI, çünkü OS kısıtları farklı:
/// - **Android**: `flutter_foreground_task` ile GERÇEK bir foreground service
///   (kalıcı bir bildirimle, bu Android'in zorunlu tuttuğu bir şey) —
///   istenen aralıkta (Kontrol Ekibi 15sn, diğerleri 1dk) güvenilir çalışır.
///   Bu servis AYRI bir izolede çalışır, ana uygulamanın (AuthService/
///   ApiClient) durumunu paylaşamaz — bu yüzden kendi token okuma/yenileme
///   mantığı var (bkz. `_LocationTaskHandler`, aynı `flutter_secure_storage`
///   anahtarlarını okur).
/// - **iOS**: `flutter_foreground_task` iOS'ta güvenilir DEĞİL (resmi
///   belgesine göre arka planda ~15 dk'da bir ~30sn çalışıyor, saha takibi
///   için yetersiz). Onun yerine geolocator'ın "Her Zaman" izni + arka plan
///   konum modu (`AppleSettings.allowBackgroundLocationUpdates`, Info.plist'te
///   `UIBackgroundModes: location`) ile ana izolede SÜREKLİ bir position
///   stream'i dinlenir, gelen her konum `interval` kadar süre geçtiyse
///   sunucuya gönderilir (throttle).
/// - **Web/masaüstü** (sadece yerel geliştirme testi için): eski basit,
///   sadece uygulama açıkken çalışan `Timer.periodic`.
class LocationService {
  LocationService(this._apiClient);

  final ApiClient _apiClient;
  final _positionController = StreamController<Position>.broadcast();
  Timer? _fallbackTimer;
  StreamSubscription<Position>? _iosSubscription;
  DateTime? _lastSentAt;

  /// Her başarılı konum okumasında yayınlanır — Kontrol Ekibi ekranı bunu
  /// dinleyerek en yakın ekipmanı yeniden sorgular.
  Stream<Position> get positionStream => _positionController.stream;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    // Arka planda takip için "Her Zaman" izni istenir (Android 10+/iOS ayrı
    // bir sistem diyaloğu gösterir) — reddedilirse servis yine de foreground'da
    // (uygulama açıkken) çalışmaya devam eder, sadece arka planda durur.
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }
    return true;
  }

  Future<void> start({Duration interval = ApiConfig.locationInterval}) async {
    if (!await _ensurePermission()) return;

    if (_isAndroid) {
      await _startAndroidForegroundService(interval);
    } else if (_isIOS) {
      await _startIosBackgroundStream(interval);
    } else {
      _startFallbackTimer(interval);
    }
  }

  Future<void> stop() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _iosSubscription?.cancel();
    _iosSubscription = null;
    if (_isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ==================== Android: gerçek foreground service ====================

  Future<void> _startAndroidForegroundService(Duration interval) async {
    final notifPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'abb_kontrol_location',
        channelName: 'Konum Takibi',
        channelDescription: 'Saha ekibi konumunuz düzenli olarak paylaşılıyor.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(interval.inMilliseconds),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(interval.inMilliseconds),
          allowWakeLock: true,
        ),
      );
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'ABB Kontrol',
        notificationText: 'Konumunuz saha takibi için paylaşılıyor',
        callback: startLocationTaskCallback,
      );
    }
  }

  // ==================== iOS: sürekli stream + throttle ====================

  Future<void> _startIosBackgroundStream(Duration interval) async {
    await _iosSubscription?.cancel();
    _iosSubscription =
        Geolocator.getPositionStream(
          locationSettings: AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.other,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          ),
        ).listen((position) {
          if (!_positionController.isClosed) _positionController.add(position);
          final now = DateTime.now();
          if (_lastSentAt == null || now.difference(_lastSentAt!) >= interval) {
            _lastSentAt = now;
            unawaited(_sendPosition(position));
          }
        });
  }

  // ==================== Fallback (web/masaüstü) ====================

  void _startFallbackTimer(Duration interval) {
    _fallbackTimer?.cancel();
    unawaited(_sendOnceForeground());
    _fallbackTimer = Timer.periodic(interval, (_) => _sendOnceForeground());
  }

  Future<void> _sendOnceForeground() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!_positionController.isClosed) _positionController.add(position);
      await _sendPosition(position);
    } catch (_) {
      // Sessizce yut: konum gönderimi başarısız olsa da uygulama akışı bozulmamalı.
    }
  }

  Future<void> _sendPosition(Position position) async {
    try {
      await _apiClient.dio.post('/api/locations', data: {'lat': position.latitude, 'lng': position.longitude});
    } catch (_) {
      // Sessizce yut.
    }
  }
}

// ==================== Android foreground task izolesi ====================

/// Callback her zaman top-level (veya static) bir fonksiyon olmalı — aksi
/// halde foreground service çalışmaz.
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

/// Ana izoleden TAMAMEN ayrı çalışır — AuthService/ApiClient'a erişemez,
/// bu yüzden token'ı doğrudan `flutter_secure_storage`'dan okur (AuthService
/// ile AYNI anahtarlarla, bkz. `core/auth_service.dart`) ve 401 alırsa
/// kendi refresh mantığını çalıştırır.
class _LocationTaskHandler extends TaskHandler {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, connectTimeout: const Duration(seconds: 15)));
  final _storage = const FlutterSecureStorage();

  static const _accessKey = 'abb_access_token';
  static const _refreshKey = 'abb_refresh_token';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _sendLocation();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_sendLocation());
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      FlutterForegroundTask.sendDataToMain({'lat': position.latitude, 'lng': position.longitude});
      await _postLocation(position, await _storage.read(key: _accessKey));
    } catch (_) {
      // Sessizce yut — bir sonraki periyotta tekrar denenecek.
    }
  }

  Future<void> _postLocation(Position position, String? token) async {
    if (token == null) return;
    try {
      await _dio.post(
        '/api/locations',
        data: {'lat': position.latitude, 'lng': position.longitude},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) return;
      final refreshToken = await _storage.read(key: _refreshKey);
      if (refreshToken == null) return;
      final refreshRes = await _dio.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
      final newAccess = refreshRes.data['accessToken'] as String;
      await _storage.write(key: _accessKey, value: newAccess);
      await _dio.post(
        '/api/locations',
        data: {'lat': position.latitude, 'lng': position.longitude},
        options: Options(headers: {'Authorization': 'Bearer $newAccess'}),
      );
    }
  }
}
