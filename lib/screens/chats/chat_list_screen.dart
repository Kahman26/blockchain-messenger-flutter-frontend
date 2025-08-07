import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
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
  late ChatService _chatService;
  Future<List<dynamic>>? _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<ChatService>(context, listen: false);
    _loadChats(); 
  }

  void _loadChats() {
    setState(() {
      _chatsFuture = _chatService.fetchChats();
    });
  }

  void _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.logout();
    if (success && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список чатов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loadChats,
          ),
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
          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка загрузки чатов: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет чатов'));
          }

          final chats = snapshot.data!;
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
                onTap: () async {
                  final members = await _chatService.fetchChatMembers(chat['chat_id']);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat['chat_id'],
                        chatName: chat['chat_name'] ?? 'Чат',
                        members: members,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
