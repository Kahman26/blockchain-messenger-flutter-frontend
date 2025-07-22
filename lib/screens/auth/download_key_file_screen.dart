import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';

import 'show_mnemonic_screen.dart';
import '../../utils/download_helper/download_helper.dart';

class DownloadKeyFileScreen extends StatelessWidget {
  final String email;
  final String encryptedKey;
  final String mnemonic;

  const DownloadKeyFileScreen({
    Key? key,
    required this.email,
    required this.encryptedKey,
    required this.mnemonic,
  }) : super(key: key);

  Future<String> _saveToDownloadDir(BuildContext context) async {
    try {
      final decoded = base64Decode(encryptedKey);
      final compressed = ZLibEncoder().encode(decoded);
      final content = jsonEncode({
        'type': 'e2e_key_file',
        'version': '1',
        'email': email,
        'compressed_key': base64Encode(compressed),
      });

      final bytes = Uint8List.fromList(utf8.encode(content));
      final fileName = 'private_key_${DateTime.now().millisecondsSinceEpoch}.e2e';

      return await saveFileToDownloads(bytes, fileName);
    } catch (e) {
      throw Exception('Ошибка при сохранении файла: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сохраните ключ')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Скачайте файл восстановления и храните его в надёжном месте. '
              'Он потребуется при входе в аккаунт.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Скачать файл ключа'),
              onPressed: () async {
                try {
                  final path = await _saveToDownloadDir(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ Файл сохранён: $path'),
                  ));
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShowMnemonicScreen(mnemonic: mnemonic),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('❌ $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
