import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef OnMessageReceived = void Function(Map<String, dynamic>);

class WebSocketService {
  WebSocketChannel? _channel;
  final _storage = const FlutterSecureStorage();

  OnMessageReceived? onMessage;

  Future<void> connect() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    final apiUrl = dotenv.env['API_URL'] ?? 'localhost:8000';
    final uri = Uri.parse('ws://$apiUrl/ws?token=$token');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (event) {
        print("WS recv: $event");
        
        final data = json.decode(event);
        if (onMessage != null) {
          onMessage!(data);
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
      },
      onDone: () {
        print('🔌 WebSocket закрыт');
      },
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(message));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
