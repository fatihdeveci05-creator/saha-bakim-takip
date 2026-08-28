import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/constants.dart';

/// Uygulama açıkken (foreground) ~1 dakikada bir konum gönderir.
///
/// NOT: Bu, PLAN.md'deki "arka planda ~1 dk'da bir konum güncellemesi"
/// gereksiniminin sadece uygulama açıkken çalışan bir sürümüdür. Uygulama
/// kapalıyken/arka plandayken de çalışması için Android'de foreground service
/// bildirimi + arka plan konum izni (workmanager veya flutter_background_service),
/// iOS'ta "Always" konum izni + significant-change location updates gerekir —
/// bu, ayrı bir native kurulum gerektirdiğinden şimdilik kapsam dışı bırakıldı.
class LocationService {
  LocationService(this._apiClient);

  final ApiClient _apiClient;
  Timer? _timer;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    return true;
  }

  Future<void> _sendOnce() async {
    try {
      if (!await _ensurePermission()) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _apiClient.dio.post(
        '/api/locations',
        data: {'lat': position.latitude, 'lng': position.longitude},
      );
    } catch (_) {
      // Sessizce yut: konum gönderimi başarısız olsa da uygulama akışı bozulmamalı.
    }
  }

  void start() {
    if (_timer != null) return;
    unawaited(_sendOnce());
    _timer = Timer.periodic(ApiConfig.locationInterval, (_) => _sendOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
