import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'mnemonic_restore_screen.dart';

class LoadKeyFileScreen extends StatelessWidget {
  final String email;

  const LoadKeyFileScreen({Key? key, required this.email}) : super(key: key);

  Future<void> _loadFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,  // Выбираем любой файл
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.single.bytes == null) {
        throw Exception('Файл не выбран');
      }

      final file = result.files.single;

      // Проверяем расширение файла вручную
      if (!file.name.toLowerCase().endsWith('.e2e')) {
        throw Exception('Неверное расширение файла. Ожидается .e2e');
      }

      final content = utf8.decode(file.bytes!);
      final data = jsonDecode(content);

      if (data['type'] != 'e2e_key_file' || data['compressed_key'] == null) {
        throw Exception('Недопустимый формат файла');
      }

      final compressed = base64Decode(data['compressed_key']);
      final decompressed = ZLibDecoder().decodeBytes(compressed);
      final encryptedKeyBase64 = base64Encode(decompressed);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MnemonicRestoreScreen(
            email: email,
            encryptedPrivateKey: encryptedKeyBase64,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Загрузите файл ключа")),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.folder_open),
          label: const Text("Выбрать файл"),
          onPressed: () => _loadFile(context),
        ),
      ),
    );
  }
}
