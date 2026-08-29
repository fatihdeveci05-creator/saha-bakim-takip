import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/constants.dart';

/// Uygulama açıkken (foreground) periyodik olarak konum gönderir — varsayılan
/// periyot 1 dk, Kontrol Ekibi için (100m yarıçaplı ekipman algılaması için)
/// `start(interval: ApiConfig.kontrolLocationInterval)` ile daha sık çağrılır.
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
  final _positionController = StreamController<Position>.broadcast();

  /// Her başarılı konum okumasında yayınlanır — Kontrol Ekibi ekranı bunu
  /// dinleyerek en yakın ekipmanı yeniden sorgular.
  Stream<Position> get positionStream => _positionController.stream;

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
      if (!_positionController.isClosed) _positionController.add(position);
      await _apiClient.dio.post(
        '/api/locations',
        data: {'lat': position.latitude, 'lng': position.longitude},
      );
    } catch (_) {
      // Sessizce yut: konum gönderimi başarısız olsa da uygulama akışı bozulmamalı.
    }
  }

  void start({Duration interval = ApiConfig.locationInterval}) {
    if (_timer != null) return;
    unawaited(_sendOnce());
    _timer = Timer.periodic(interval, (_) => _sendOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
