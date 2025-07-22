import 'dart:convert';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import 'key_utils.dart';

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
}
