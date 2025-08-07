import 'package:dio/dio.dart';
import '../utils/secure_storage.dart';
import '../utils/crypto_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class ChatService {
  final Dio _dio;
  final String baseUrl;

  ChatService(this._dio, {required this.baseUrl});

  Future<List<dynamic>> fetchChats() async {
    try {
      final response = await _dio.get('/chats/');
      if (response.statusCode == 200) {
        return response.data['chats'];
      } else {
        throw Exception('Failed to load chats');
      }
    } catch (e) {
      print('Fetch chats error: $e');
      return [];
    }
  }


  Future<void> sendMessage({
    required int chatId,
    required List<Map<String, dynamic>> receivers,
    required String message,
  }) async {
    final email = await SecureStorage.read('current_email');
    final privateKey = await SecureStorage.read('private_key_$email');

    if (privateKey == null) throw Exception("🔐 Приватный ключ не найден");

    final signature = CryptoUtilsService.signMessage(message, privateKey);

    final encryptedMessages = receivers
      .where((receiver) => receiver['public_key'] != null && receiver['id'] != null)
      .map((receiver) {
        final encrypted = CryptoUtilsService.encryptMessage(message, receiver['public_key']);
        return {
          'receiver_id': receiver['id'],
          'encrypted_message': encrypted,
          'signature': signature,
        };
      })
      .toList();

    await _dio.post(
      '/chats/$chatId/send',
      data: encryptedMessages,
    );
  }


  Future<List<Map<String, dynamic>>> fetchMessages(int chatId) async {
    final token = await SecureStorage.read('access_token');
    final response = await _dio.get(
      '$baseUrl/chats/$chatId/messages',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return List<Map<String, dynamic>>.from(response.data['messages']);
  }


  Future<List<Map<String, dynamic>>> fetchChatMembers(int chatId) async {
    final token = await SecureStorage.read('access_token');
    final response = await _dio.get(
      '$baseUrl/chats/$chatId/members',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return List<Map<String, dynamic>>.from(response.data['members']);
  }

}
