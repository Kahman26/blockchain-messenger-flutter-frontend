import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/secure_storage.dart';
import '../chats/chat_list_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'select_restore_method_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() {
      _loading = false;
    });

    if (success) {
      final email = _emailController.text.trim();

      final existingKey = await SecureStorage.read('private_key_$email');
      final existingEncryptedKey = await SecureStorage.read('encrypted_private_key_$email');

      if (existingKey != null || existingEncryptedKey != null) {
        final jwt = await SecureStorage.read('jwt_not_confirmed');
        
        if (jwt != null) {
          await SecureStorage.write('jwt', jwt);
        }

        await SecureStorage.delete('encrypted_private_key_$email');
        await SecureStorage.delete('jwt_not_confirmed');
        // 🔐 Ключ уже есть — переходим сразу к чатам
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatListScreen(),
          ),
        );
      } else {
        // 🔐 Ключа нет — выбор метода восстановления
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SelectRestoreMethodScreen(email: email),
          ),
        );
      }
    } else {
      setState(() {
        _error = 'Неверный email или пароль';
      });
    }
  }

  @override
    Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Вход')),
        body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            children: [
            TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
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
                onPressed: _loading ? null : _handleLogin,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Войти'),
            ),
            const SizedBox(height: 10),

            TextButton(
                onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
                },
                child: const Text('Ещё нет аккаунта? Зарегистрироваться'),
            ),

            TextButton(
                onPressed: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                },
                child: const Text('Забыли пароль? Восстановить'),
                ),

            ],
        ),
        ),
    );
    }
}
