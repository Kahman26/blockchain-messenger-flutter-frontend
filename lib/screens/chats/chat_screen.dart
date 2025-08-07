import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/chat_service.dart';
import '../../services/websocket_service.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/web_workers/worker_bridge_stub.dart'
    if (dart.library.html) '../../utils/web_workers/worker_bridge.dart';


class ChatScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final List<Map<String, dynamic>> members; // [{id, public_key, username, last_seen}]

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

  late ChatService _chatService;
  late WebSocketService _wsService;
  
  List<Map<String, dynamic>> _liveMessages = [];

  List<Message> _messages = [];
  String? _currentUserEmail;
  int? _currentUserId;
  String? _privateKey;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<ChatService>(context, listen: false);

    _wsService = WebSocketService();

    _wsService.onMessage = (data) async {
      if (data['from_user_id'] == _currentUserId) return;

      final encrypted = data['payload'];
      final decrypted = CryptoUtilsService.decryptMessage(encrypted, _privateKey!);

      final newMsg = Message(
        fromUserId: data['from_user_id'],
        content: decrypted,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _liveMessages.add({
            'from_user_id': data['from_user_id'],
            'payload': decrypted,
          });
          _messages.add(newMsg);
        });

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
    };

    _wsService.connect();

    _initialize();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
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

  final newMsg = Message(
    fromUserId: _currentUserId!,
    content: text,
    timestamp: DateTime.now(),
  );

  // 1️⃣ Сначала отображаем сообщение и очищаем поле
  setState(() {
    _messages.add(newMsg);
    _controller.clear();
  });

  _scrollToBottom();

  // 2️⃣ Сохраняем в кэш сразу
  final prefs = await SharedPreferences.getInstance();
  final cacheKey = 'decrypted_chat_${widget.chatId}';
  final updatedCache = _messages.map((m) => {
    'from_user_id': m.fromUserId,
    'content': m.content,
    'timestamp': m.timestamp.toIso8601String(),
  }).toList();
  await prefs.setString(cacheKey, jsonEncode(updatedCache));

  // 3️⃣ Отправляем на сервер — асинхронно (не блокирует UI)
  unawaited(_sendMessageToBackend(text));
}

Future<void> _sendMessageToBackend(String text) async {
  try {
    await _chatService.sendMessage(
      chatId: widget.chatId,
      message: text,
      receivers: widget.members,
    );

    for (var member in widget.members) {
      final toUserId = member['id'];
      final pubKey = member['public_key'];
      final encrypted = CryptoUtilsService.encryptMessage(text, pubKey);
      final signature = CryptoUtilsService.signMessage(text, _privateKey!);

      _wsService.sendMessage({
        'to_user_id': toUserId,
        'payload': encrypted,
        'signature': signature,
        'chat_id': widget.chatId,
      });
    }
  } catch (e) {
    print('Ошибка при отправке сообщения: $e');
    // 🔴 Можно добавить визуальное уведомление или retry
  }
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
