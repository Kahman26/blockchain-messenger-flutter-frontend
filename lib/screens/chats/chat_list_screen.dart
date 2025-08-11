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

  // --- added fields ---
  List<dynamic> _chats = []; // locally cached chats (populated when future resolves)
  List<Map<String, dynamic>> _users = []; // search results for users
  bool _isSearchingUsers = false;
  bool _isCreatingChat = false;

  String _searchQuery = '';

  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<ChatService>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
    _loadChats();
}


  void _loadChats() {
    setState(() {
      // store returned future and fill _chats when it completes
      _chatsFuture = _chatService.fetchChats().then((chats) {
        _chats = chats;
        return chats;
      });
    });
  }


  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }


  Future<void> _searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _users = [];
        _isSearchingUsers = false;
      });
      return;
    }

    setState(() => _isSearchingUsers = true);
    try {
      final res = await _chatService.searchUsers(q);

      // Собираем идентификаторы/имена пользователей, с которыми уже есть private-чаты
      final existingUserIds = <int>{};
      final existingDisplayNames = <String>{};

      for (final c in _chats) {
        final type = (c['chat_type'] ?? '').toString();
        if (type != 'private') continue;

        final members = c['members'];
        if (members != null && members is List) {
          for (final m in members) {
            if (m is int) existingUserIds.add(m);
            if (m is Map && m['id'] != null) existingUserIds.add(m['id'] as int);
          }
        } else {
          final name = (c['chat_name'] ?? '').toString();
          if (name.isNotEmpty) existingDisplayNames.add(name.toLowerCase());
        }
      }

      final filtered = res.where((u) {
        final uid = u['id'];
        final display = (u['display_name'] ?? u['username'] ?? '').toString().toLowerCase();
        if (uid != null && existingUserIds.contains(uid)) return false;
        if (existingDisplayNames.contains(display)) return false;
        return true;
      }).toList();

      setState(() {
        _users = List<Map<String, dynamic>>.from(filtered);
      });
    } catch (e) {
      debugPrint('searchUsers error: $e');
      setState(() {
        _users = [];
      });
    } finally {
      if (mounted) setState(() => _isSearchingUsers = false);
    }
  }


  Future<void> _handleUserTap(Map<String, dynamic> user) async {
    if (_isCreatingChat) return; // avoid double clicks
    // try to find existing private chat with this user
    dynamic existingChat;
    try {
      existingChat = _chats.firstWhere((c) {
        final type = (c['chat_type'] ?? '').toString();
        if (type != 'private') return false;

        // if members list exists — prefer checking ids
        final members = c['members'];
        if (members != null && members is List) {
          return members.any((m) {
            if (m is int) return m == user['id'];
            if (m is Map<String, dynamic>) return m['id'] == user['id'];
            return false;
          });
        }

        // fallback: match chat_name to display_name (legacy)
        final chatName = (c['chat_name'] ?? '').toString();
        final displayName = (user['display_name'] ?? '').toString();
        return chatName.isNotEmpty && chatName == displayName;
      }, orElse: () => null);
    } catch (e) {
      existingChat = null;
    }

    if (existingChat != null) {
      // open existing chat
      try {
        final members = await _chatService.fetchChatMembers(existingChat['chat_id']);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: existingChat['chat_id'],
              chatName: existingChat['chat_name'] ?? 'Чат',
              members: members,
            ),
          ),
        );
        return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка при загрузке участников: $e'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    // create new private chat
    setState(() => _isCreatingChat = true);
    try {
      final newChat = await _chatService.createPrivateChat(user['id']);
      // add to local cache so user sees it in the list without full reload
      setState(() {
        _chats.insert(0, newChat);
      });

      // try to fetch members for navigation
      List<Map<String, dynamic>> members = [];
      try {
        members = await _chatService.fetchChatMembers(newChat['chat_id']);
      } catch (_) {
        // ignore — we still can open chat with empty members
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: newChat['chat_id'],
            chatName: newChat['chat_name'] ?? (user['display_name'] ?? 'Чат'),
            members: members,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Не удалось создать чат: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isCreatingChat = false);
    }
  }

  void _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.logout();
    if (success && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              focusNode: _searchFocusNode,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Поиск по чатам и пользователям...',
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                final q = value.trim();
                setState(() {
                  _searchQuery = q.toLowerCase();
                });
                _searchUsers(q);
              },
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _chatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки чатов: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет чатов'));
          }

          // use the snapshot data for rendering (we also keep _chats in sync via _loadChats)
          final chats = snapshot.data!
              .where((chat) {
                final name = (chat['chat_name'] ?? '').toString().toLowerCase();
                return _searchQuery.isEmpty || name.contains(_searchQuery);
              })
              .toList();

          chats.sort((a, b) {
            final aDate = DateTime.tryParse(a['last_message_timestamp'] ?? '') ?? DateTime(1970);
            final bDate = DateTime.tryParse(b['last_message_timestamp'] ?? '') ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

          // build combined list: chats first, users under header (users are results of search)
          return Stack(
            children: [
              ListView(
                children: [
                  if (chats.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...chats.map((chat) {
                      final title = chat['chat_name'] ?? 'Без названия';
                      final type = chat['chat_type'] ?? '';
                      final rawTime = chat['last_message_timestamp'] ?? chat['last_message_time'];
                        String formattedTime = '';
                        if (rawTime != null) {
                          DateTime? dt;
                          if (rawTime is String && rawTime.isNotEmpty) {
                            try {
                              dt = DateTime.parse(rawTime);
                            } catch (_) {
                              dt = null;
                            }
                          } else if (rawTime is DateTime) {
                            dt = rawTime;
                          }
                          if (dt != null) {
                            formattedTime = DateFormat.Hm().format(dt);
                          }
                        }
                      return ListTile(
                        leading: CircleAvatar(child: Text(title[0])),
                        title: Text(title),
                        subtitle: Text('Тип: $type'),
                        trailing: Text(formattedTime),
                        onTap: () async {
                          FocusScope.of(context).unfocus();
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
                    }).toList(),
                  ],
                  if (_users.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Пользователи', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ..._users.map((user) {
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user['display_name'] ?? 'Без имени'),
                        subtitle: Text(user['email'] ?? ''),
                        onTap: () {
                          FocusScope.of(context).unfocus(); 
                          _handleUserTap(user);
                        },
                      );
                    }).toList(),
                  ],
                  if (_users.isEmpty && _searchQuery.isNotEmpty && !_isSearchingUsers) ...[
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('Ничего не найдено')),
                    ),
                  ],
                ],
              ),

              // small overlay loader when creating chat
              if (_isCreatingChat)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),

              // small inline search users loader
              if (_isSearchingUsers)
                const Positioned(
                  right: 16,
                  top: 8,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
