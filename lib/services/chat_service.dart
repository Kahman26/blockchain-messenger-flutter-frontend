import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class ChatService {
  final Dio _dio = Dio();
  final _storage = FlutterSecureStorage(
    webOptions: WebOptions(),
  );

  final String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

  Future<List<dynamic>> fetchChats() async {
    try {
      final token = await _storage.read(key: 'jwt');
      if (token == null) throw Exception('Token not found');

      final response = await _dio.get(
        '$baseUrl/chats/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data['chats']; // должен быть список чатов
      } else {
        throw Exception('Failed to load chats');
      }
    } catch (e) {
      print('Fetch chats error: $e');
      return [];
    }
  }
}
