import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_user.dart';
import 'constants.dart';

class AuthService extends ChangeNotifier {
  AuthService() : _plainDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  final Dio _plainDio;
  final _storage = const FlutterSecureStorage();

  static const _accessKey = 'abb_access_token';
  static const _refreshKey = 'abb_refresh_token';

  String? accessToken;
  String? refreshToken;
  AuthUser? currentUser;
  bool ready = false;

  bool get isLoggedIn => currentUser != null;

  Future<void> _persist() async {
    if (accessToken != null) {
      await _storage.write(key: _accessKey, value: accessToken);
    } else {
      await _storage.delete(key: _accessKey);
    }
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    } else {
      await _storage.delete(key: _refreshKey);
    }
  }

  Future<void> _fetchMe() async {
    final res = await _plainDio.get(
      '/api/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    currentUser = AuthUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> init() async {
    if (ready) return;
    accessToken = await _storage.read(key: _accessKey);
    refreshToken = await _storage.read(key: _refreshKey);
    if (accessToken != null) {
      try {
        await _fetchMe();
      } catch (_) {
        await tryRefresh();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> tryRefresh() async {
    if (refreshToken == null) {
      await logout();
      return false;
    }
    try {
      final res = await _plainDio.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
      accessToken = res.data['accessToken'] as String;
      await _persist();
      await _fetchMe();
      notifyListeners();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final res = await _plainDio.post('/api/auth/login', data: {'email': email, 'password': password});
    accessToken = res.data['accessToken'] as String;
    refreshToken = res.data['refreshToken'] as String;
    currentUser = AuthUser.fromJson(res.data['user'] as Map<String, dynamic>);
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
    await _persist();
    notifyListeners();
  }
}
