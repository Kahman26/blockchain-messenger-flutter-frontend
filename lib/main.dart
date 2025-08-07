import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/chats/chat_list_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'utils/secure_storage.dart';
import 'utils/dio_interceptor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
 
  final dio = Dio(BaseOptions(
    baseUrl: 'http://${dotenv.env['API_URL'] ?? 'localhost:8000'}',
  ));
  
  dio.interceptors.add(TokenInterceptor(dio));
  
  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>(create: (_) => dio),
        Provider<AuthService>(
          create: (context) => AuthService(Provider.of<Dio>(context, listen: false)),
        ),
        Provider<ChatService>(
          create: (context) => ChatService(
            Provider.of<Dio>(context, listen: false),
            baseUrl: dio.options.baseUrl,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          return FutureBuilder<bool>(
            future: authService.isLoggedIn(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return snapshot.data == true 
                  ? const ChatListScreen() 
                  : const LoginScreen();
            },
          );
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}