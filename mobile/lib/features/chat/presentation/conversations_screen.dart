import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/chat/chat_socket.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

/// The Messages inbox: latest message per person, live-updated by the socket.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<void>? _reconnected;
  Timer? _debounce;
  String? _myId;

  @override
  void initState() {
    super.initState();
    ref.read(mockAuthProvider).userId().then((v) {
      if (mounted) setState(() => _myId = v);
    });
    final socket = ref.read(chatSocketProvider)..connect();
    _events = socket.events.listen((m) {
      // Any inbound activity can change the list order / unread counts.
      if (m['type'] == 'message' ||
          m['type'] == 'read_receipt' ||
          m['type'] == 'delivered' ||
          m['type'] == 'presence') {
        _refreshSoon();
      }
    });
    _reconnected = socket.reconnected.listen((_) => _refreshSoon());
  }

  void _refreshSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      ref.invalidate(chatUnreadProvider);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _reconnected?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Messages',
            style: GoogleFonts.poppins(
                fontSize: 19, fontWeight: FontWeight.w700)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _empty(
            Icons.wifi_off_rounded, 'Couldn’t load messages', 'Pull to retry.'),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(conversationsProvider),
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  _empty(Icons.forum_outlined, 'No messages yet',
                      'Start a conversation from any property — tap Message on a listing.'),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(
                  height: 1, indent: 78, color: AppColors.border),
              itemBuilder: (_, i) => _tile(list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(Conversation c) {
    final unread = c.unread > 0;
    final mineLast = c.lastSenderId == _myId;
    final preview = (mineLast ? 'You: ' : '') + c.lastMessage;
    return InkWell(
      onTap: () {
        context.push('/chat/${c.userId}', extra: {
          'name': c.userName,
          'image': c.userImage,
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: (c.userImage != null && c.userImage!.isNotEmpty)
                  ? NetworkImage(c.userImage!)
                  : null,
              child: (c.userImage == null || c.userImage!.isEmpty)
                  ? Text(c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(preview.isEmpty ? '📷 Photo' : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: unread ? AppColors.ink : AppColors.inkSoft,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_time(c.lastTime),
                    style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: unread ? AppColors.primary : AppColors.inkSoft,
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.w400)),
                const SizedBox(height: 6),
                if (unread)
                  Container(
                    padding: const EdgeInsets.all(5),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: Text(c.unread > 99 ? '99+' : '${c.unread}',
                        style: GoogleFonts.poppins(
                            fontSize: 9,
                            height: 1,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.inkSoft),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 12.5, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  String _time(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return wd[d.weekday - 1];
    }
    return '${d.day}/${d.month}/${d.year % 100}';
  }
}
