import 'package:flutter/material.dart';

class ShowMnemonicScreen extends StatelessWidget {
  final String mnemonic;

  const ShowMnemonicScreen({Key? key, required this.mnemonic}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Секретная фраза')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Запиши эту кодовую фразу и храни в надёжном месте. Она нужна для восстановления доступа:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SelectableText(
              mnemonic,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Я записал. Перейти ко входу'),
            ),
          ],
        ),
      ),
    );
  }
}
