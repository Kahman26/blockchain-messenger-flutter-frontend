import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

class TokenInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  TokenInterceptor(this._dio)
      : _storage = const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        return handler.next(err);
      }

      try {
        final deviceId = await _storage.read(key: 'device_id');
        final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
        final response = await refreshDio.post('/auth/refresh', data: {
          'refresh_token': refreshToken,
          'device_id': deviceId,
        });

        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        await _storage.write(key: 'access_token', value: newAccessToken);
        await _storage.write(key: 'refresh_token', value: newRefreshToken);

        // 🔁 Перезапускаем оригинальный запрос с новым токеном
        final opts = err.requestOptions;

        final newOptions = Options(
          method: opts.method,
          headers: {
            ...opts.headers,
            'Authorization': 'Bearer $newAccessToken',
          },
        );

        final retryResponse = await _dio.request(
          opts.path,
          data: opts.data,
          queryParameters: opts.queryParameters,
          options: newOptions,
        );

        return handler.resolve(retryResponse);
      } catch (e) {
        return handler.next(err); 
      }
    }

    return handler.next(err);
  }
}