import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/chat_service.dart';
import '../../utils/crypto_utils.dart';

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

  List<_Message> _messages = [];
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

    final messages = await _chatService.fetchMessages(widget.chatId);
    final decryptedMessages = await _decryptMessages(messages, privKey);

    setState(() {
      _currentUserEmail = email;
      _currentUserId = userId;
      _privateKey = privKey;
      _messages = decryptedMessages;
      _loading = false;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  }

  Future<List<_Message>> _decryptMessages(List<Map<String, dynamic>> raw, String privKey) async {
    return raw.map((msg) {
      String decrypted;
      try {
        decrypted = CryptoUtilsService.decryptMessage(msg['encrypted_data'], privKey);
      } catch (_) {
        decrypted = '[🔒 Не удалось расшифровать]';
      }
      return _Message(
        fromUserId: msg['from_user_id'],
        content: decrypted,
        timestamp: DateTime.parse(msg['timestamp']),
      );
    }).toList();
  }


  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _privateKey == null) return;

    final others = widget.members.where((u) => u['id'] != _currentUserId).toList();

    await _chatService.sendMessage(
      chatId: widget.chatId,
      message: text,
      receivers: widget.members, // ВСЕ, включая себя
    );

    setState(() {
      _messages.add(_Message(
        fromUserId: _currentUserId!,
        content: text,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
    });

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

class _Message {
  final int fromUserId;
  final String content;
  final DateTime timestamp;

  _Message({
    required this.fromUserId,
    required this.content,
    required this.timestamp,
  });
}
