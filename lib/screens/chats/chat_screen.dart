import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/chat_service.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/web_workers/worker_bridge_stub.dart'
    if (dart.library.html) '../../utils/web_workers/worker_bridge.dart';


class ChatScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final List<Map<String, dynamic>> members; // [{id, publicKey, username}]

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.members,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final _chatService = ChatService();

  List<Message> _messages = [];
  String? _currentUserEmail;
  int? _currentUserId;
  String? _privateKey;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final email = await _storage.read(key: 'current_email');
    final privKey = await _storage.read(key: 'private_key_$email');
    final userId = int.tryParse(await _storage.read(key: 'user_id') ?? '');

    if (email == null || privKey == null || userId == null) {
      setState(() => _loading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'decrypted_chat_${widget.chatId}';

    List<Message> messages;

    if (prefs.containsKey(cacheKey)) {
      // Загрузка из кэша
      try {
        final cachedJson = prefs.getString(cacheKey)!;
        final cachedList = jsonDecode(cachedJson) as List;
        messages = cachedList.map((e) => Message(
          fromUserId: e['from_user_id'],
          content: e['content'],
          timestamp: DateTime.parse(e['timestamp']),
        )).toList();
      } catch (e) {
        // Кэш повреждён — fallback на расшифровку
        final fetched = await _chatService.fetchMessages(widget.chatId);
        messages = await _decryptMessages(fetched, privKey);

        final toCache = messages.map((m) => {
          'from_user_id': m.fromUserId,
          'content': m.content,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList();

        await prefs.setString(cacheKey, jsonEncode(toCache));
      }
    } else {
      // Кэша нет — расшифровываем
      final fetched = await _chatService.fetchMessages(widget.chatId);
      messages = await _decryptMessages(fetched, privKey);

      final toCache = messages.map((m) => {
        'from_user_id': m.fromUserId,
        'content': m.content,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList();

      await prefs.setString(cacheKey, jsonEncode(toCache));
    }

    setState(() {
      _currentUserEmail = email;
      _currentUserId = userId;
      _privateKey = privKey;
      _messages = messages;
      _loading = false;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  }



  Future<List<Message>> _decryptMessages(List<Map<String, dynamic>> raw, String privKey) async {
    if (kIsWeb) {
      final completer = Completer<List<Message>>();
      final worker = MessageDecryptWorker(
        rawMessages: raw,
        privateKey: privKey,
        onDecrypted: (result) {
          final messages = result.map((e) => Message(
            fromUserId: e['from_user_id'],
            content: e['content'],
            timestamp: DateTime.parse(e['timestamp']),
          )).toList();
          completer.complete(messages);
        },
      );
      worker.decrypt();
      return completer.future;
    } else {
        // compute для Android/iOS
        return await compute(
          decryptMessagesSync,
          DecryptMessagesArgs(raw, privKey),
        );
      }
  }


  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _privateKey == null) return;

    await _chatService.sendMessage(
      chatId: widget.chatId,
      message: text,
      receivers: widget.members,
    );

    final newMsg = Message(
      fromUserId: _currentUserId!,
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(newMsg);
      _controller.clear();
    });

    // Обновляем кэш уже после setState
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'decrypted_chat_${widget.chatId}';
    final updatedCache = _messages.map((m) => {
      'from_user_id': m.fromUserId,
      'content': m.content,
      'timestamp': m.timestamp.toIso8601String(),
    }).toList();

    await prefs.setString(cacheKey, jsonEncode(updatedCache));

    _scrollToBottom();
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = _currentUserId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.chatName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.fromUserId == me;
                      final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                      final bubbleColor = isMe ? Colors.blue[100] : Colors.grey[300];
                      final time = DateFormat('HH:mm').format(msg.timestamp);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Column(
                          crossAxisAlignment: align,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg.content),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Введите сообщение...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _handleSend,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class Message {
  final int fromUserId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.fromUserId,
    required this.content,
    required this.timestamp,
  });
}
