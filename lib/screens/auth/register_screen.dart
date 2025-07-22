import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/secure_storage.dart';
import '../../utils/key_utils.dart';
import '../../utils/web_workers/worker_bridge.dart';
import 'confirm_email_screen.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _handleRegister() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final keys = await compute(CryptoUtilsService.generateRsaKeyPairSync, null);
      final email = _emailController.text.trim();

      final mnemonic = CryptoUtilsService.generateMnemonic();
      final encryptedPrivateKey = await compute(
        encryptPrivateKeySync,
        EncryptPrivateKeyArgs(keys['private_key']!, mnemonic),
      );

      await SecureStorage.write('private_key_$email', encryptedPrivateKey);
      await SecureStorage.write('mnemonic_$email', mnemonic);
      await SecureStorage.write('current_email', email);

      final success = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        publicKey: keys['public_key']!,
      );

      debugPrint('🔍 keys_$email: $keys');
      debugPrint('-'*100);
      debugPrint('🔐 Сгенерирована мнемоника: $mnemonic');
      debugPrint('🔐 Зашифрованный приватный ключ: $encryptedPrivateKey');

      if (!mounted) return;
      setState(() => _loading = false);

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConfirmEmailScreen(email: email),
          ),
        );
      } else {
        setState(() {
          _error = 'Ошибка при регистрации';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка: $e';
      });
    }
  }

  void _handleWebKeyGen() {
    setState(() => _loading = true);

    final worker = KeyGenWorker(onKeysAndEncryptedReady: (keys) async {
      final email = _emailController.text.trim();

      await SecureStorage.write('private_key_$email', keys['encrypted']!);
      await SecureStorage.write('mnemonic_$email', keys['mnemonic']!);
      await SecureStorage.write('current_email', email);

      final success = await _authService.register(
        email: email,
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        publicKey: keys['public_key']!,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConfirmEmailScreen(email: email),
          ),
        );
      } else {
        setState(() => _error = 'Ошибка при регистрации');
      }
    });

    worker.generateKeys();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Логин'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Номер телефона'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      if (kIsWeb) {
                        _handleWebKeyGen(); // для Web
                      } else {
                        _handleRegister(); // для Android/iOS
                      }
                    },
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Зарегистрироваться'),
            ),
          ],
        ),
      ),
    );
  }
}
