import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:image_picker_web/image_picker_web.dart'; // неактуально

import 'mnemonic_restore_screen.dart';

// import 'package:base45/src/base45.dart';

import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';

class ScanQrScreen extends StatelessWidget {
  final String email;

  const ScanQrScreen({Key? key, required this.email}) : super(key: key);

  void _handleQRData(BuildContext context, String qrString) {
    try {
      debugPrint('📥 Считан QR: $qrString');

      final jsonData = jsonDecode(qrString);
      debugPrint('📖 Parsed JSON: $jsonData');

      if (jsonData is! Map ||
          jsonData['type'] != 'e2e_key' ||
          jsonData['compressed_key'] == null) {
        debugPrint("⚠️ Неверный формат QR: $jsonData");
        _showError(context, "QR-код недействителен");
        return;
      }

      final compressedKey = base64Decode(jsonData['compressed_key']);
      debugPrint("📦 Распакованный base64 (compressed) length: ${compressedKey.length}");

      final decompressed = ZLibDecoder().decodeBytes(compressedKey);
      debugPrint("🔓 Распакованный ключ длина: ${decompressed.length}");

      final decryptedKeyBase64 = base64Encode(decompressed);
      debugPrint("✅ Готово. Перенаправляем на экран восстановления");

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MnemonicRestoreScreen(
            email: email,
            encryptedPrivateKey: decryptedKeyBase64,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('❌ Ошибка при обработке QR: $e');
      debugPrintStack(stackTrace: st);
      _showError(context, "Ошибка при обработке QR");
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканирование QR')),
      body: QRCodeDartScanView(
        typeScan: TypeScan.live,
        onCapture: (result) {
          try {
            final qrText = result.text;
            if (qrText.isNotEmpty) {
              _handleQRData(context, qrText);
            } else {
              debugPrint("⚠️ QR пустой");
              _showError(context, "QR-код пустой");
            }
          } catch (e) {
            debugPrint("❌ Ошибка в onCapture: $e");
            _showError(context, "Ошибка чтения QR: $e");
          }
        },
        imageDecodeOrientation: ImageDecodeOrientation.portrait,
      ),
    );
  }
}