import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/auth/login_screen.dart';
import 'screens/chats/chat_list_screen.dart';
import 'utils/secure_storage.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartScreen() async {
    final token = await SecureStorage.read('jwt');

    if (token != null) {
      return const ChatListScreen(); 
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: FutureBuilder<Widget>(
        future: _getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data!;
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

