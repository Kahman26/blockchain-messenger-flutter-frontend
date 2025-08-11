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


  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final token = await SecureStorage.read('access_token');
      final response = await _dio.get(
        '$baseUrl/users/search',
        queryParameters: {'q': query},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return List<Map<String, dynamic>>.from(response.data['users']);
    } catch (e) {
      print('Search users error: $e');
      return [];
    }
  }

    Future<Map<String, dynamic>> createPrivateChat(int userId) async {
    try {
      final token = await SecureStorage.read('access_token');
      final response = await _dio.post(
        '$baseUrl/chats/',
        data: {
          'chat_type': 'private',
          'other_user_id': userId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // create_chat в бэкенде возвращает {"chat_id": <id>}
      final chatId = response.data['chat_id'];
      if (chatId == null) {
        throw Exception('Failed to create chat: no chat_id returned');
      }

      // получаем полную информацию о чате, чтобы фронт мог сразу использовать chat_name и т.д.
      final infoResp = await _dio.get(
        '$baseUrl/chats/$chatId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return Map<String, dynamic>.from(infoResp.data);
    } catch (e) {
      print('Create chat error: $e');
      rethrow;
    }
  }


}
