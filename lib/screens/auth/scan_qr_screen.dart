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



// class ScanQrScreen extends StatelessWidget {
//   final String email;

//   const ScanQrScreen({Key? key, required this.email}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Сканирование QR')),
//       body: UniversalPlatform.isWeb
//           ? _buildWebPicker(context)
//           : _buildMobileScanner(context),
//     );
//   }

//   /// Веб: заглушка с ручным вводом
//   Widget _buildWebPicker(BuildContext context) {
//     final controller = TextEditingController();

//     return Padding(
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         children: [
//           const Text('Скопируйте текст из QR-кода (или загрузите позже)'),
//           const SizedBox(height: 12),
//           TextField(
//             controller: controller,
//             maxLines: 6,
//             decoration: const InputDecoration(
//               border: OutlineInputBorder(),
//               labelText: 'Вставьте JSON из QR',
//             ),
//           ),
//           const SizedBox(height: 12),
//           ElevatedButton(
//             onPressed: () {
//               final qrString = controller.text.trim();
//               if (qrString.isEmpty) {
//                 _showError(context, "Поле пустое");
//                 return;
//               }
//               _handleQRData(context, qrString);
//             },
//             child: const Text("Продолжить"),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Мобильный сканер с отображением камеры
//   Widget _buildMobileScanner(BuildContext context) {
//     return Stack(
//       children: [
//         MobileScanner(
//           controller: MobileScannerController(
//             facing: CameraFacing.back,
//             torchEnabled: false,
//           ),
//           onDetect: (capture) {
//             final barcodes = capture.barcodes;
//             if (barcodes.isEmpty) return;

//             final rawValue = barcodes
//                 .map((b) => b.rawValue ?? '')
//                 .reduce((a, b) => a.length > b.length ? a : b);

//             if (rawValue.isNotEmpty) {
//               _handleQRData(context, rawValue);
//             }
//           }
//         ),
//         Align(
//           alignment: Alignment.bottomCenter,
//           child: Container(
//             color: Colors.black54,
//             padding: const EdgeInsets.all(12),
//             child: const Text(
//               'Наведите камеру на QR-код',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   /// Распаковка, проверка и переход
//   void _handleQRData(BuildContext context, String qrString) {
//     try {
//       final jsonData = jsonDecode(qrString);
//       if (jsonData['type'] != 'e2e_key' || jsonData['compressed_key'] == null) {
//         _showError(context, "QR-код недействителен");
//         return;
//       }

//       final compressedKey = base64Decode(jsonData['compressed_key']);
//       // final compressedKey = base45Decode(jsonData['compressed_key']);
//       final decompressed = ZLibDecoder().decodeBytes(compressedKey);
//       final decryptedKeyBase64 = base64Encode(decompressed);

//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(
//           builder: (_) => MnemonicRestoreScreen(
//             email: email,
//             encryptedPrivateKey: decryptedKeyBase64,
//           ),
//         ),
//       );
//     } catch (e) {
//       _showError(context, "Ошибка при обработке QR: $e");
//     }
//   }

//   void _showError(BuildContext context, String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }
// }
