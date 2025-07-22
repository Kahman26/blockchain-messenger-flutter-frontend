import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';
import '../../utils/secure_storage.dart';
import '../auth/login_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<dynamic>> _chatsFuture;

  void _handleLogout() async {
    final email = await SecureStorage.read('current_email');
    if (email != null) {
      await SecureStorage.delete('jwt');
      await SecureStorage.delete('user_id');
      await SecureStorage.delete('current_email');
      await SecureStorage.delete('private_key_$email');
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _chatsFuture = _chatService.fetchChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список чатов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: _handleLogout,
          ),
        ],
      ),

      body: FutureBuilder<List<dynamic>>(
        future: _chatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет чатов'));
          }

          final chats = snapshot.data!;

          // Сортировка по дате последнего сообщения, если есть поле last_message_timestamp
          chats.sort((a, b) {
            final aDate = DateTime.tryParse(a['last_message_timestamp'] ?? '') ?? DateTime(1970);
            final bDate = DateTime.tryParse(b['last_message_timestamp'] ?? '') ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final title = chat['chat_name'] ?? 'Без названия';
              final type = chat['chat_type'] ?? '';
              final time = chat['last_message_timestamp'];
              final formattedTime = time != null
                  ? DateFormat.Hm().format(DateTime.parse(time))
                  : '';

              return ListTile(
                leading: CircleAvatar(child: Text(title[0])),
                title: Text(title),
                subtitle: Text('Тип: $type'),
                trailing: Text(formattedTime),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat['chat_id'],
                        chatName: chat['chat_name'] ?? 'Чат',
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
