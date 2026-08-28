import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'constants.dart';

/// Kimlik doğrulamalı istekler için Dio istemcisi: her isteğe access token ekler,
/// 401 alınca AuthService üzerinden refresh dener ve isteği bir kez tekrarlar.
class ApiClient {
  ApiClient(this._authService) {
    _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, connectTimeout: const Duration(seconds: 15)));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authService.accessToken != null) {
            options.headers['Authorization'] = 'Bearer ${_authService.accessToken}';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _authService.tryRefresh();
            if (refreshed) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer ${_authService.accessToken}';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                // düşer, orijinal hata döner
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final AuthService _authService;
  late final Dio _dio;

  Dio get dio => _dio;
}
