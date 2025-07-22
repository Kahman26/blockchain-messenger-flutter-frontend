// lib/utils/download_helper_io.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

Future<String> saveFileToDownloads(Uint8List bytes, String fileName) async {
  if (Platform.isAndroid) {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      throw Exception('Нет разрешения на доступ к хранилищу');
    }

    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) {
      throw Exception('Не удалось найти папку загрузок');
    }

    final file = File(p.join(downloadsDir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  throw UnsupportedError('Платформа не поддерживается');
}
