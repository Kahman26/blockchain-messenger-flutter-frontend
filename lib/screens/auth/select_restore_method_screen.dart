import 'package:flutter/material.dart';
import 'recover_private_key_screen.dart';
import 'load_key_file_screen.dart';


class SelectRestoreMethodScreen extends StatelessWidget {
  final String email;

  const SelectRestoreMethodScreen({Key? key, required this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Восстановление доступа")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Выберите способ восстановления доступа к аккаунту:",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Пока заглушка
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Функция пока не реализована")),
                );
              },
              icon: const Icon(Icons.message),
              label: const Text("Ввести код с другого устройства"),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoadKeyFileScreen(email: email),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text("Использовать файл + мнемонику"),
            ),
          ],
        ),
      ),
    );
  }
}
