import 'package:flutter/material.dart';

class BackupPhraseScreen extends StatelessWidget {
  final String phrase;

  const BackupPhraseScreen({required this.phrase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Секретная фраза')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('Запиши эту фразу и храни в безопасности!'),
            const SizedBox(height: 20),
            SelectableText(
              phrase,
              style: TextStyle(fontSize: 18, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: Text('Я сохранил'),
            )
          ],
        ),
      ),
    );
  }
}
