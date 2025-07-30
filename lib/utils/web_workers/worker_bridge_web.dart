import 'dart:html';
import 'dart:convert';

import '../crypto_utils.dart';


typedef KeyGenCallback = void Function(Map<String, String> keys);

class KeyGenWorker {
  final KeyGenCallback onKeysAndEncryptedReady;
  late Worker _worker;

  bool _waitingForEncryption = false;
  late String _privateKey;
  late String _mnemonic;

  KeyGenWorker({required this.onKeysAndEncryptedReady}) {
    _worker = Worker('workers/key_worker.js');

    _worker.onMessage.listen((event) {
      final decoded = jsonDecode(event.data);

      if (decoded is Map && decoded['cmd'] == 'encrypted') {
        // Второй этап: получено зашифрованное сообщение
        final encryptedPrivateKey = decoded['encrypted'];
        _worker.terminate();

        onKeysAndEncryptedReady({
          'private_key': _privateKey,
          'public_key': _publicKey,
          'encrypted': encryptedPrivateKey,
          'mnemonic': _mnemonic,
        });
      } else if (decoded is Map && decoded.containsKey('private_key')) {
        // Первый этап: получена пара ключей
        _privateKey = decoded['private_key'];
        _publicKey = decoded['public_key'];

        // Генерируем мнемонику в главном потоке
        _mnemonic = _generateMnemonic();

        _worker.postMessage({
          'cmd': 'encrypt_private_key',
          'privateKey': _privateKey,
          'passphrase': _mnemonic,
        });
      }
    });
  }

  late String _publicKey;

  void generateKeys() {
    _worker.postMessage('generate_rsa');
  }
}

String _generateMnemonic() {
  return CryptoUtilsService.generateMnemonic();
}


class DecryptWorker {
  final String encrypted;
  final String mnemonic;
  final void Function(String result) onDecrypted;

  late Worker _worker;

  DecryptWorker({
    required this.encrypted,
    required this.mnemonic,
    required this.onDecrypted,
  }) {
    _worker = Worker('workers/key_worker.js');

    _worker.onMessage.listen((event) {
      final decoded = jsonDecode(event.data);
      if (decoded is Map && decoded['cmd'] == 'decrypted') {
        _worker.terminate();
        onDecrypted(decoded['pem']);
      }
    });
  }

  void decrypt() {
    _worker.postMessage({
      'cmd': 'decrypt_private_key',
      'encrypted': encrypted,
      'passphrase': mnemonic,
    });
  }
}


class MessageDecryptWorker {
  final List<Map<String, dynamic>> rawMessages;
  final String privateKey;
  final void Function(List<Map<String, dynamic>> result) onDecrypted;

  late Worker _worker;

  MessageDecryptWorker({
    required this.rawMessages,
    required this.privateKey,
    required this.onDecrypted,
  }) {
    _worker = Worker('workers/key_worker.js');

    _worker.onMessage.listen((event) {
      final decoded = jsonDecode(event.data);
      if (decoded is Map && decoded['cmd'] == 'decrypted_messages') {
        _worker.terminate();
        final List<dynamic> result = decoded['messages'];
        onDecrypted(List<Map<String, dynamic>>.from(result));
      }
    });
  }

  void decrypt() {
    _worker.postMessage({
      'cmd': 'decrypt_messages',
      'messages': jsonEncode(rawMessages),
      'private_key': privateKey,
    });
  }
}

