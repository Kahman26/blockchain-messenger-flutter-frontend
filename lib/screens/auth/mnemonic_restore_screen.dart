import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' show AESFastEngine, CBCBlockCipher, KeyParameter, PaddedBlockCipher, PKCS7Padding, Pbkdf2Parameters, HMac, SHA256Digest, PBKDF2KeyDerivator;
import 'package:crypto/crypto.dart';
import 'package:basic_utils/basic_utils.dart';

import '../chats/chat_list_screen.dart';
import '../../utils/key_utils.dart';
import '../../utils/web_workers/worker_bridge.dart';

class MnemonicRestoreScreen extends StatefulWidget {
  final String email;
  final String encryptedPrivateKey;

  const MnemonicRestoreScreen({
    Key? key,
    required this.email,
    required this.encryptedPrivateKey,
  }) : super(key: key);

  @override
  State<MnemonicRestoreScreen> createState() => _MnemonicRestoreScreenState();
}

class _MnemonicRestoreScreenState extends State<MnemonicRestoreScreen> {
  final _mnemonicController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Восстановление ключа")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Введите вашу мнемонику для расшифровки приватного ключа:",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mnemonicController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'например: apple flower hero ...',
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _onSubmit,
                    child: const Text("Расшифровать и продолжить"),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final mnemonic = _mnemonicController.text.trim();

    try {
      String pem;

      if (kIsWeb) {
        final completer = Completer<String>();
        final worker = DecryptWorker(
          encrypted: widget.encryptedPrivateKey,
          mnemonic: mnemonic,
          onDecrypted: (result) => completer.complete(result),
        );
        worker.decrypt();
        pem = await completer.future;
      } else {
        pem = await compute(
          decryptPrivateKeySync,
          DecryptPrivateKeyArgs(widget.encryptedPrivateKey, mnemonic),
        );
      }

      if (!pem.contains("PRIVATE KEY")) {
        throw Exception("Неверная мнемоника или повреждённый ключ");
      }

      await _storage.write(key: 'private_key_${widget.email}', value: pem);

      final jwt = await _storage.read(key: 'jwt_not_confirmed');
      final refreshToken = await _storage.read(key: 'refresh_token');

      if (jwt != null && refreshToken != null) {
        await _storage.write(key: 'access_token', value: jwt);
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }

      await _storage.delete(key: 'encrypted_private_key_${widget.email}');
      await _storage.delete(key: 'jwt_not_confirmed');
      
      // Ниже Debug
      final currentEmail = await _storage.read(key: 'current_email');
      final privKeyPem = await _storage.read(key: 'private_key_$currentEmail');
      final userId = int.tryParse(await _storage.read(key: 'user_id') ?? '0') ?? 0;

      debugPrint('🔍 jwt: $jwt');
      debugPrint('🔍 current_email: $currentEmail');
      debugPrint('🔍 private_key_$currentEmail: $privKeyPem');
      debugPrint('🔍 user_id: $userId');

      debugPrint('🔐 Приватный ключ:, $pem');
      // Выше Debug

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _error = "Ошибка: ${e.toString()}";
        _loading = false;
      });
    }
  }

  Uint8List pbkdf2(String pass, List<int> salt, int iterations, int keyLength) {
    final key = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, keyLength));
    return key.process(utf8.encode(pass) as Uint8List);
  }

  Uint8List aesDecrypt(Uint8List data, Uint8List key) {
    final cipher = CBCBlockCipher(AESFastEngine());
    final params = ParametersWithIV(KeyParameter(key), Uint8List(16)); // IV = 16 null bytes
    cipher.init(false, params);

    final padded = Uint8List(data.length);
    for (int offset = 0; offset < data.length; offset += cipher.blockSize) {
      cipher.processBlock(data, offset, padded, offset);
    }

    // Remove PKCS7 padding
    int pad = padded.last;
    return padded.sublist(0, padded.length - pad);
  }
}
