import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/export.dart' hide State, Padding;
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String chatName;

  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _storage = FlutterSecureStorage(
    webOptions: WebOptions(),
  );


  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final jwt = await _storage.read(key: 'jwt');
    final currentEmail = await _storage.read(key: 'current_email');
    final privKeyPem = await _storage.read(key: 'private_key_$currentEmail');
    final userId = int.tryParse(await _storage.read(key: 'user_id') ?? '0') ?? 0;

    debugPrint('🔍 jwt: $jwt');
    debugPrint('🔍 current_email: $currentEmail');
    debugPrint('🔍 private_key_$currentEmail: $privKeyPem');
    debugPrint('🔍 user_id: $userId');

    final allKeys = await _storage.readAll();
    debugPrint('All keys in storage: ${allKeys.keys}');

    debugPrint('🔍 Проверка хранилища:');
    final allValues = await _storage.readAll();
    allValues.forEach((key, value) {
    debugPrint('$key: $value');
    });

    if (jwt == null) {
    debugPrint('🚫 JWT не найден');
    }
    if (privKeyPem == null) {
    debugPrint('🚫 Приватный ключ не найден для private_key_$currentEmail');
    }
    if (userId == 0) {
    debugPrint('🚫 user_id не найден или равен 0');
    }

    if (jwt == null || privKeyPem == null || currentEmail == null || userId == 0) {
    print("🚫 Не найдены токен, email или приватный ключ");
    return;
    }


    try {
      // 1. Получаем участников чата с публичными ключами
      final response = await http.get(
        Uri.parse('http://80.93.60.56:8000/chats/${widget.chatId}'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (response.statusCode != 200) {
        print('Ошибка получения участников');
        return;
      }
      final data = jsonDecode(response.body);
      final List receivers = data['members'];

      // 2. Подписываем сообщение приватным ключом
      final signature = await _signMessage(message, privKeyPem);

      // 3. Шифруем сообщение для каждого участника
      final List payload = [];
      for (var receiver in receivers) {
        final receiverId = receiver['user_id'];
        final receiverPubKeyPem = receiver['public_key'];
        if (receiverPubKeyPem == null) continue;

        final encrypted = await _encryptMessage(message, receiverPubKeyPem);
        payload.add({
          "receiver_id": receiverId,
          "encrypted_message": encrypted,
          "signature": signature,
        });
      }

      // 4. Отправляем на бэкенд
      final sendRes = await http.post(
        Uri.parse('http://80.93.60.56:8000/chats/${widget.chatId}/send'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (sendRes.statusCode == 200) {
        print("✅ Сообщение отправлено");
        _messageController.clear();
      } else {
        print("❌ Ошибка отправки: ${sendRes.body}");
      }
    } catch (e) {
      print("⚠️ Ошибка при отправке: $e");
    }
  }

  Future<String> _encryptMessage(String message, String pubPem) async {
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(pubPem);

    final encryptor = OAEPEncoding(RSAEngine())
        ..init(
        true,
        PublicKeyParameter<RSAPublicKey>(publicKey),
        );

    final input = Uint8List.fromList(utf8.encode(message));
    final output = encryptor.process(input);

    return base64Encode(output);
    }

  Future<String> _signMessage(String message, String privPem) async {
    final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privPem);

    final signer = Signer('SHA-256/RSA');
    final privParams = PrivateKeyParameter<RSAPrivateKey>(privateKey);
    signer.init(true, privParams);

    final sig = signer.generateSignature(Uint8List.fromList(utf8.encode(message)));
    return base64Encode((sig as RSASignature).bytes);
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatName)),
      body: Column(
        children: [
          const Expanded(child: Center(child: Text('🔐 История чата (скоро)'))),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
