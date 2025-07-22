import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';


String encryptPrivateKeySync(EncryptPrivateKeyArgs args) {
  final key = KeyUtils.deriveKeyFromPassphrase(args.passphrase);
  final cipher = PaddedBlockCipher("AES/CBC/PKCS7");
  final iv = Uint8List(16); // фиксированный IV (можно улучшить)
  final params = PaddedBlockCipherParameters(
    ParametersWithIV(KeyParameter(key), iv),
    null,
  );
  cipher.init(true, params);
  final encrypted = cipher.process(utf8.encode(args.pemKey) as Uint8List);
  return base64Encode(encrypted);
}


class EncryptPrivateKeyArgs {
  final String pemKey;
  final String passphrase;

  EncryptPrivateKeyArgs(this.pemKey, this.passphrase);
}


class DecryptPrivateKeyArgs {
  final String encrypted;
  final String passphrase;

  DecryptPrivateKeyArgs(this.encrypted, this.passphrase);
}

String decryptPrivateKeySync(DecryptPrivateKeyArgs args) {
  return KeyUtils.decryptPrivateKey(args.encrypted, args.passphrase);
}


class KeyUtils {
  static Future<Map<String, String>> generateRSAKeyPair() async {
        final pair = CryptoUtils.generateRSAKeyPair();

        final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(pair.privateKey as RSAPrivateKey);
        final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(pair.publicKey as RSAPublicKey);

        return {
            'private_key': privatePem,
            'public_key': publicPem,
        };
        }

  static String rsaPrivateKeyToPem(RSAPrivateKey privateKey) {
    return CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
  }

  static RSAPrivateKey rsaPrivateKeyFromPem(String pem) {
    return CryptoUtils.rsaPrivateKeyFromPem(pem);
  }

  static Uint8List deriveKeyFromPassphrase(String passphrase, {int iterations = 100000}) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final salt = utf8.encode("your_static_salt"); // Лучше использовать индивидуальный
    pbkdf2.init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, 32));
    return pbkdf2.process(utf8.encode(passphrase) as Uint8List);
  }


  static String decryptPrivateKey(String encryptedBase64, String passphrase) {
    final key = deriveKeyFromPassphrase(passphrase);
    final cipher = PaddedBlockCipher("AES/CBC/PKCS7");
    final iv = Uint8List(16); // такой же IV
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    );
    cipher.init(false, params);
    final decrypted = cipher.process(base64Decode(encryptedBase64));
    return utf8.decode(decrypted);
  }
}
