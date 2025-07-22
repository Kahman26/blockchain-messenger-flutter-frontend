
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _handleRequestCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _authService.requestPasswordResetCode(
      _emailController.text.trim(),
    );

    setState(() => _loading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: _emailController.text),
        ),
      );
    } else {
      setState(() {
        _error = 'Ошибка при отправке кода';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление пароля')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _handleRequestCode,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Отправить код'),
            ),
          ],
        ),
      ),
    );
  }
}
