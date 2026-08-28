import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/app_notification.dart';

const _pollInterval = Duration(seconds: 30);

class NotificationService extends ChangeNotifier {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;
  Timer? _timer;
  List<AppNotification> items = [];

  int get unreadCount => items.where((n) => !n.okundu).length;

  Future<void> refresh() async {
    try {
      final res = await _apiClient.dio.get('/api/notifications');
      items = (res.data as List<dynamic>).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {
      // Sessizce yut: bildirim yenileme başarısız olsa da uygulama akışı bozulmamalı.
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _apiClient.dio.post('/api/notifications/$id/read');
      final index = items.indexWhere((n) => n.id == id);
      if (index != -1) {
        items[index] = AppNotification(
          id: items[index].id,
          tip: items[index].tip,
          mesaj: items[index].mesaj,
          relatedWorkOrderId: items[index].relatedWorkOrderId,
          okundu: true,
          createdAt: items[index].createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  void start() {
    if (_timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
