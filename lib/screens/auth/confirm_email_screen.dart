import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/secure_storage.dart';
import 'login_screen.dart';
import 'show_mnemonic_screen.dart';
//import 'show_qr_screen.dart';
import 'download_key_file_screen.dart';

class ConfirmEmailScreen extends StatefulWidget {
  final String email;
  ConfirmEmailScreen({super.key, required this.email});

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final _codeController = TextEditingController();
  late AuthService _authService;
  bool _loading = false;
  String? _error;

  late String generatedMnemonic;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _authService.confirmEmail(
      widget.email,
      _codeController.text.trim(),
    );

    setState(() {
      _loading = false;
    });

    if (success) {
      final email = widget.email;
      final mnemonic = await SecureStorage.read('mnemonic_$email');
      final encryptedKey = await SecureStorage.read('encrypted_private_key_$email');

      if (mnemonic == null || encryptedKey == null) {
        setState(() => _error = 'Ошибка: не найден ключ или мнемоника');
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DownloadKeyFileScreen(
            email: email,
            encryptedKey: encryptedKey,
            mnemonic: mnemonic,
          ),
        ),
      );
    } else {
      setState(() {
        _error = 'Неверный код';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подтвердите почту')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Мы отправили код на ${widget.email}'),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Код'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _handleConfirm,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Подтвердить'),
            ),
          ],
        ),
      ),
    );
  }
}
