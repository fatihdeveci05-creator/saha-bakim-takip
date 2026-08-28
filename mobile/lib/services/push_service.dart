import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/navigation.dart';
import '../screens/work_order_detail_screen.dart';

/// Uygulama kapalıyken/arka plandayken gelen mesajlar için ayrı bir isolate'te
/// çalışabilen üst düzey (top-level) fonksiyon olmalı — FCM eklentisinin gerektirdiği kural.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bildirim payload'lı mesajları OS zaten otomatik gösterir; burada ek bir şey gerekmiyor.
}

/// FCM izin/token kaydı, ön planda gelen mesajlarda bildirim listesini tazeleme,
/// arka plan/kapalıyken tıklanan bildirimde ilgili iş emrine yönlendirme.
class PushService {
  PushService(this._apiClient, {required this.onForegroundMessage});

  final ApiClient _apiClient;
  final VoidCallback onForegroundMessage;

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);
    messaging.onTokenRefresh.listen(_registerToken);

    FirebaseMessaging.onMessage.listen((_) => onForegroundMessage());
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage);
  }

  Future<void> _registerToken(String token) async {
    try {
      await _apiClient.dio.post(
        '/api/users/me/device-token',
        data: {'token': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'},
      );
    } catch (_) {
      // Sessizce yut: token kaydı başarısız olsa da uygulama akışı bozulmamalı.
    }
  }

  void _handleTap(RemoteMessage message) {
    final workOrderIdStr = message.data['workOrderId'];
    final workOrderId = workOrderIdStr != null ? int.tryParse(workOrderIdStr) : null;
    if (workOrderId == null) return;
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: workOrderId)));
  }
}
