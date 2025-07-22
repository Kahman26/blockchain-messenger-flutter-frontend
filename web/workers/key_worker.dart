import 'dart:html';
import 'dart:convert';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';

void main() {
  DedicatedWorkerGlobalScope self = DedicatedWorkerGlobalScope.instance;

  self.onMessage.listen((event) {
    final message = event.data;

    // Генерация RSA
    if (message == 'generate_rsa') {
      final pair = CryptoUtils.generateRSAKeyPair();

      final privateKey = CryptoUtils.encodeRSAPrivateKeyToPem(pair.privateKey as RSAPrivateKey);
      final publicKey = CryptoUtils.encodeRSAPublicKeyToPem(pair.publicKey as RSAPublicKey);

      final response = jsonEncode({
        'private_key': privateKey,
        'public_key': publicKey,
      });

      self.postMessage(response);
    }

    // Шифрование приватного ключа
    else if (message is Map && message['cmd'] == 'encrypt_private_key') {
      final pemKey = message['privateKey'];
      final passphrase = message['passphrase'];

      final key = _deriveKeyFromPassphrase(passphrase);
      final cipher = PaddedBlockCipher("AES/CBC/PKCS7");
      final iv = Uint8List(16); // ⚠ можно заменить на случайный + сохранять
      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );
      cipher.init(true, params);

      final encrypted = cipher.process(utf8.encode(pemKey) as Uint8List);
      final encryptedBase64 = base64Encode(encrypted);

      self.postMessage(jsonEncode({
        'cmd': 'encrypted',
        'encrypted': encryptedBase64,
      }));
    }

    else if (message is Map && message['cmd'] == 'decrypt_private_key') {
      final encryptedBase64 = message['encrypted'];
      final passphrase = message['passphrase'];

      final key = _deriveKeyFromPassphrase(passphrase);
      final cipher = PaddedBlockCipher("AES/CBC/PKCS7");
      final iv = Uint8List(16);
      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );
      cipher.init(false, params);

      try {
        final decrypted = cipher.process(base64Decode(encryptedBase64));
        final pem = utf8.decode(decrypted);

        self.postMessage(jsonEncode({
          'cmd': 'decrypted',
          'pem': pem,
        }));
      } catch (e) {
        self.postMessage(jsonEncode({
          'cmd': 'decrypted',
          'pem': '',
        }));
      }
    }
    // Неизвестная команда
    else {
      self.postMessage('Unknown command: $message');
    }
  });
}

// Копия из KeyUtils.deriveKeyFromPassphrase
Uint8List _deriveKeyFromPassphrase(String passphrase, {int iterations = 100000}) {
  final salt = utf8.encode("your_static_salt");
  final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  pbkdf2.init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, 32));
  return pbkdf2.process(utf8.encode(passphrase) as Uint8List);
}
