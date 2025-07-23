import 'package:flutter/material.dart';
import '../../utils/secure_storage.dart';
import '../../utils/crypto_utils.dart';
import '../chats/chat_list_screen.dart';

class RecoverPrivateKeyScreen extends StatefulWidget {
  final String email;

  const RecoverPrivateKeyScreen({super.key, required this.email});

  @override
  State<RecoverPrivateKeyScreen> createState() => _RecoverPrivateKeyScreenState();
}

class _RecoverPrivateKeyScreenState extends State<RecoverPrivateKeyScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  void _recoverKey() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final mnemonic = _controller.text.trim();

    try {
        final encrypted = await SecureStorage.read('encrypted_private_key_${widget.email}');

        if (encrypted == null) {
            setState(() {
                _error = 'Зашифрованный ключ не найден';
                _isLoading = false;
            });
            return;
        }
        // Дешифруем приватный ключ
        final privateKeyPem = await CryptoUtilsService.decryptPrivateKeyFromMnemonic(mnemonic, encrypted);

        if (privateKeyPem == null) {
            setState(() {
            _error = 'Неверная кодовая фраза';
            _isLoading = false;
            });
            return;
        }

      // Сохраняем приватный ключ в хранилище
      await SecureStorage.write('private_key_${widget.email}', privateKeyPem);

      // Здесь можно вызвать backend, чтобы получить JWT и user_id по email и паролю,
      // если они ещё не сохранены в хранилище. Пока пропустим.

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    } catch (e) {
      setState(() {
        _error = 'Ошибка расшифровки: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление ключа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Введите вашу кодовую фразу, чтобы восстановить доступ:'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _recoverKey,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Восстановить'),
            ),
          ],
        ),
      ),
    );
  }
}
