import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.read(apiClientProvider)),
);

/// REST side of chat: hydrate the conversation list, load a thread's history,
/// and the unread badge count. The live updates ride the WebSocket
/// ([ChatSocket]); this just paints the initial state and survives reconnects.
class ChatRepository {
  ChatRepository(this._api);
  final Dio _api;

  Future<List<Conversation>> conversations() async {
    final r = await _api.get('/chat/conversations');
    return (r.data as List)
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<({List<ChatMessage> messages, ChatPartner partner})> history(
    String userId,
  ) async {
    final r = await _api.get('/chat/with/$userId');
    final d = Map<String, dynamic>.from(r.data as Map);
    final msgs = ((d['messages'] as List?) ?? const [])
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final partner = ChatPartner.fromJson(
      Map<String, dynamic>.from((d['partner'] as Map?) ?? const {}),
    );
    return (messages: msgs, partner: partner);
  }

  Future<int> unreadCount() async {
    try {
      final r = await _api.get('/chat/unread-count');
      return (r.data['count'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRead(String userId) async {
    try {
      await _api.post('/chat/with/$userId/read');
    } catch (_) {/* best-effort */}
  }
}

/// Conversation list for the Messages screen (re-fetched on open + on socket
/// activity via invalidation).
final conversationsProvider = FutureProvider<List<Conversation>>(
  (ref) => ref.read(chatRepositoryProvider).conversations(),
);

/// Total unread messages, for the home Messages badge. Kept alive; invalidate
/// to refresh after reading a thread or when a new message arrives.
final chatUnreadProvider = FutureProvider<int>(
  (ref) => ref.read(chatRepositoryProvider).unreadCount(),
);
