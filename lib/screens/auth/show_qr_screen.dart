import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'show_mnemonic_screen.dart';

class ShowQRScreen extends StatelessWidget {
  final String email;
  final String encryptedKey;
  final String mnemonic;

  const ShowQRScreen({
    Key? key,
    required this.email,
    required this.encryptedKey,
    required this.mnemonic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      final decoded = base64Decode(encryptedKey);
      debugPrint("🔐 Encrypted key base64 length: ${encryptedKey.length}");
      debugPrint("🔓 Decoded key bytes length: ${decoded.length}");

      final compressed = ZLibEncoder().encode(decoded);
      debugPrint("📦 Compressed key length: ${compressed.length}");

      final compressedBase64 = base64Encode(compressed);
      debugPrint("🧬 Compressed base64 length: ${compressedBase64.length}");

      final payload = jsonEncode({
        'type': 'e2e_key',
        'version': '1',
        'email': email,
        'compressed_key': compressedBase64,
      });

      debugPrint("✅ Final QR payload length: ${payload.length}");
      debugPrint("📤 QR payload: $payload");

      return Scaffold(
        appBar: AppBar(title: const Text('QR-код восстановления')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Сохраните этот QR-код — он потребуется для восстановления доступа!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 400.0,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ShowMnemonicScreen(mnemonic: mnemonic),
                    ),
                  );
                },
                child: const Text('Я сохранил QR. Далее'),
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      debugPrint("❌ Ошибка при генерации QR: $e");
      debugPrintStack(stackTrace: st);
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text("Не удалось создать QR-код")),
      );
    }
  }
}

