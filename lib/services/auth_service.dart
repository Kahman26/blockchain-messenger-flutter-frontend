import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';


class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  final _storage = FlutterSecureStorage(
    webOptions: WebOptions(),
  );

  final String baseUrl = 'http://' + (dotenv.env['API_URL'] ?? 'localhost:8000');

  Future<bool> login(String email, String password) async {
    try {
      final String deviceId = const Uuid().v4();

      final response = await _dio.post(
        '$baseUrl/auth/login',
        data: {
          'email': email, 
          'password': password,
          'device_id': deviceId,
          },
      );

      final token = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];
      final userId = response.data['user_id'];

      if (token != null && refreshToken != null) {
        await _saveNotConfirmedTokens(token, refreshToken);
        await _storage.write(key: 'device_id', value: deviceId);
        await _storage.write(key: 'current_email', value: email);
        if (userId != null) {
          await _storage.write(key: 'user_id', value: userId.toString());
        }
        return true;
      }

      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }


  Future<String?> getToken() => _storage.read(key: 'access_token');


  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required String phoneNumber,
    required String publicKey,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/register',
        data: {
          'email': email,
          'password': password,
          'username': username,
          'phone_number': phoneNumber,
          'public_key': publicKey,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }


  Future<bool> confirmEmail(String email, String code) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/confirm-email',
        data: {
          'email': email,
          'code': code,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Confirm email error: $e');
      return false;
    }
  }


  Future<bool> requestPasswordResetCode(String email) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/request-verification',
        data: {'email': email},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Request reset code error: $e');
      return false;
    }
  }


  Future<bool> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/reset-password',
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }


  Future<bool> refreshTokens() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      final deviceId = await _storage.read(key: 'device_id');

      if (refreshToken == null) return false;

      final response = await _dio.post(
        '$baseUrl/auth/refresh',
        data: {
          'refresh_token': refreshToken,
          'device_id': deviceId,
          },
      );

      if (response.statusCode == 200) {
        await _saveTokens(
          response.data['access_token'],
          response.data['refresh_token'],
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Refresh token error: $e');
      return false;
    }
  }


  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> _saveNotConfirmedTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'jwt_not_confirmed', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }


  Future<String?> getAccessToken() => _storage.read(key: "access_token");
  Future<String?> getRefreshToken() => _storage.read(key: "refresh_token");


  Future<void> clearTokens() async {
    await _storage.delete(key: "access_token");
    await _storage.delete(key: "refresh_token");
  }


  Future<bool> logout() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _dio.post(
          '$baseUrl/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
 
      await _storage.deleteAll();
      return true;
    } catch (e) {
      print('Logout error: $e');
      return false;
    }
  }


  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;

    return true;
  }

}
