import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';


class AuthService {
  final Dio _dio = Dio();
  final _storage = FlutterSecureStorage(
    webOptions: WebOptions(),
  );

  final String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final token = response.data['access_token'];
      final userId = response.data['user_id']; 

      debugPrint(token);
      debugPrint(userId.toString());

      if (token != null) {
        await _storage.write(key: 'jwt_not_confirmed', value: token);
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

  Future<String?> getToken() => _storage.read(key: 'jwt');

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
}
