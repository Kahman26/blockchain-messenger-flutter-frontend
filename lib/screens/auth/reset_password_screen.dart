// lib/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _handleReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _authService.resetPassword(
      widget.email,
      _codeController.text.trim(),
      _passwordController.text,
    );

    setState(() => _loading = false);

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _error = 'Ошибка сброса пароля';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сброс пароля')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Email: ${widget.email}'),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Код из письма'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Новый пароль'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _handleReset,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Сбросить пароль'),
            ),
          ],
        ),
      ),
    );
  }
}
