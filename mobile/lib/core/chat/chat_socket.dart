import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/token_store.dart';
import '../config/env.dart';

/// App-wide chat socket. Kept alive for the app's lifetime so messages, read
/// receipts and presence keep flowing while the user moves between screens.
final chatSocketProvider = Provider<ChatSocket>((ref) {
  final s = ChatSocket(ref.read(tokenStoreProvider));
  ref.onDispose(s.dispose);
  return s;
});

/// A resilient WebSocket client for 1:1 chat.
///
/// - Authenticates by putting the backend session JWT in the URL path
///   (`/chat/ws/{token}`) — a WS handshake can't carry an Authorization header.
/// - Exposes a single broadcast [events] stream of decoded server frames; every
///   screen filters the frames it cares about (`message`, `read_receipt`,
///   `delivered`, `typing`, `presence`).
/// - Reconnects automatically with capped exponential backoff and announces a
///   successful *re*connect on [reconnected] so screens can re-sync history.
class ChatSocket {
  ChatSocket(this._tokens);
  final TokenStore _tokens;

  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _connecting = false;
  bool _closed = false;
  bool _everConnected = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<void> get reconnected => _reconnected.stream;
  bool get isConnected => _ch != null;

  /// Idempotent — safe to call from every chat screen's initState.
  Future<void> connect() async {
    if (_ch != null || _connecting) return;
    _connecting = true;
    _closed = false;
    try {
      final token = _tokens.cached ?? await _tokens.read();
      if (token == null || token.isEmpty) return; // not signed in → no socket
      final ch = WebSocketChannel.connect(
        Uri.parse('${Env.wsBaseUrl}/chat/ws/$token'),
      );
      await ch.ready; // throws on a failed handshake
      _ch = ch;
      _attempt = 0;
      if (_everConnected) _reconnected.add(null);
      _everConnected = true;
      _sub = ch.stream.listen(
        _onData,
        onDone: _onDropped,
        onError: (_) => _onDropped(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onData(dynamic raw) {
    try {
      final m = jsonDecode(raw as String);
      if (m is Map<String, dynamic>) _events.add(m);
    } catch (_) {/* ignore malformed frame */}
  }

  void _onDropped() {
    _sub?.cancel();
    _sub = null;
    _ch = null;
    if (!_closed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _retry?.cancel();
    _attempt += 1;
    final secs = (3 * _attempt).clamp(3, 30);
    _retry = Timer(Duration(seconds: secs), connect);
  }

  void _send(Map<String, dynamic> data) {
    final ch = _ch;
    if (ch == null) {
      connect(); // reconnect; caller's optimistic UI will reconcile on echo
      return;
    }
    ch.sink.add(jsonEncode(data));
  }

  void sendMessage({
    required String receiverId,
    String message = '',
    String imageUrl = '',
    String messageType = 'text',
    String? propertyId,
  }) {
    _send({
      'type': 'message',
      'receiver_id': receiverId,
      'message': message,
      'image_url': imageUrl,
      'message_type': messageType,
      if (propertyId != null && propertyId.isNotEmpty) 'property_id': propertyId,
    });
  }

  void markRead(String senderId) =>
      _send({'type': 'read', 'sender_id': senderId});

  void sendTyping(String receiverId) =>
      _send({'type': 'typing', 'receiver_id': receiverId});

  /// Tear down without auto-reconnect (call on sign-out).
  Future<void> disconnect() async {
    _closed = true;
    _retry?.cancel();
    await _sub?.cancel();
    _sub = null;
    await _ch?.sink.close(ws_status.normalClosure);
    _ch = null;
  }

  void dispose() {
    disconnect();
    _events.close();
    _reconnected.close();
  }
}
