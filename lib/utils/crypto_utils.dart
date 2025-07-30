import 'dart:convert';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import 'key_utils.dart';
import '../screens/chats/chat_screen.dart';

class CryptoUtilsService {
  /// Генерация пары ключей
  static Map<String, String> generateRsaKeyPairSync(_) {
    final pair = CryptoUtils.generateRSAKeyPair();

    final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(pair.privateKey as RSAPrivateKey);
    final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(pair.publicKey as RSAPublicKey);

    return {
      'private_key': privatePem,
      'public_key': publicPem,
    };
  }

  // Генерация BIP39 мнемоники
  static String generateMnemonic() {
    final mnemonic = Mnemonic.generate(Language.english, entropyLength: 128,);  // 128 бит = 12 слов
    return mnemonic.sentence;
  }

  // Расшифровка приватного ключа из зашифрованной кодовой фразы
  static Future<String?> decryptPrivateKeyFromMnemonic(String mnemonic, String encryptedKey) async {
    try {
      final decrypted = KeyUtils.decryptPrivateKey(encryptedKey, mnemonic);
      return decrypted;
    } catch (e) {
      return null;
    }
  }


  static String encryptMessage(String message, String publicKeyPem) {
    final RSAPublicKey publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);

    final cipher = RSAEngine()
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final Uint8List input = Uint8List.fromList(utf8.encode(message));
    final Uint8List encrypted = cipher.process(input);
    return base64Encode(encrypted);
  }


  static String decryptMessage(String base64Message, String privateKeyPem) {
    final RSAPrivateKey privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);

    final cipher = RSAEngine()
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final Uint8List encryptedBytes = base64Decode(base64Message);
    final Uint8List decrypted = cipher.process(encryptedBytes);
    return utf8.decode(decrypted);
  }


  static String signMessage(String message, String privateKeyPem) {
    final RSAPrivateKey privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);

    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final hash = crypto.sha256.convert(utf8.encode(message));
    final sig = signer.generateSignature(Uint8List.fromList(hash.bytes)) as RSASignature;

    return base64Encode(sig.bytes);
  }


  static bool verifySignature(String message, String signatureBase64, String publicKeyPem) {
    final RSAPublicKey publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);

    final signer = Signer('SHA-256/RSA')
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

    final hash = crypto.sha256.convert(utf8.encode(message));
    final signatureBytes = base64Decode(signatureBase64);
    final sig = RSASignature(signatureBytes);

    return signer.verifySignature(Uint8List.fromList(hash.bytes), sig);
  }

}


class DecryptMessagesArgs {
  final List<Map<String, dynamic>> rawMessages;
  final String privateKey;

  DecryptMessagesArgs(this.rawMessages, this.privateKey);
}

List<Message> decryptMessagesSync(DecryptMessagesArgs args) {
  return args.rawMessages.map((msg) {
    String decrypted;
    try {
      decrypted = CryptoUtilsService.decryptMessage(msg['encrypted_data'], args.privateKey);
    } catch (_) {
      decrypted = '[🔒 Не удалось расшифровать]';
    }
    return Message(
      fromUserId: msg['from_user_id'],
      content: decrypted,
      timestamp: DateTime.parse(msg['timestamp']),
    );
  }).toList();
}


