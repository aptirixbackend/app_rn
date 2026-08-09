import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/chat/chat_socket.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

/// Optional listing context when the chat is opened from a property.
class ChatProperty {
  const ChatProperty({required this.id, this.title = '', this.image = '', this.location = ''});
  final String id, title, image, location;
}

/// A one-to-one conversation, WhatsApp-style: live bubbles with delivery ticks,
/// typing indicator, presence and read receipts over the [ChatSocket], hydrated
/// from REST history and kept in sync across reconnects.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    this.peerName,
    this.peerImage,
    this.property,
  });

  final String peerId;
  final String? peerName;
  final String? peerImage;
  final ChatProperty? property;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatSocket _socket;
  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<void>? _reconnected;

  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<ChatMessage> _messages = [];
  final List<String> _pending = []; // temp ids awaiting server echo (FIFO)

  String? _myId;
  bool _loading = true;
  bool _noAuth = false;
  ChatPartner? _partner;
  bool _peerOnline = false;
  bool _peerTyping = false;
  Timer? _typingClear;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  String get _peer => widget.peerId;

  String get _title =>
      widget.peerName?.trim().isNotEmpty == true
          ? widget.peerName!.trim()
          : (_partner?.userName ?? 'RentoRent User');

  String? get _avatar => widget.peerImage?.isNotEmpty == true
      ? widget.peerImage
      : _partner?.userImage;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(chatSocketProvider);
    _socket.connect();
    _events = _socket.events.listen(_onEvent);
    _reconnected = _socket.reconnected.listen((_) => _loadHistory(silent: true));
    _init();
  }

  Future<void> _init() async {
    _myId = await ref.read(mockAuthProvider).userId();
    // Chat needs the backend session token; without it the socket can't attach.
    final store = ref.read(tokenStoreProvider);
    final tok = store.cached ?? await store.read();
    if (tok == null || tok.isEmpty) {
      if (mounted) {
        setState(() {
          _noAuth = true;
          _loading = false;
        });
      }
      return;
    }
    await _loadHistory();
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await ref.read(chatRepositoryProvider).history(_peer);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(res.messages);
        _pending.clear(); // server truth supersedes any in-flight optimism
        _partner = res.partner;
        _peerOnline = res.partner.online;
        _loading = false;
      });
      _socket.markRead(_peer); // live read receipt to the peer
      _refreshBadges();
      _scrollToBottomSoon();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onEvent(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['type']) {
      case 'message':
        final msg = ChatMessage.fromJson(m);
        final fromPeer = msg.senderId == _peer && msg.receiverId == _myId;
        final mine = msg.senderId == _myId && msg.receiverId == _peer;
        if (fromPeer) {
          if (_messages.any((x) => x.id == msg.id)) break; // already have it
          setState(() {
            _messages.add(msg);
            _peerTyping = false;
          });
          _socket.markRead(_peer);
          _refreshBadges();
          _scrollToBottomSoon();
        } else if (mine) {
          setState(() {
            if (_pending.isNotEmpty) {
              final temp = _pending.removeAt(0);
              final i = _messages.indexWhere((x) => x.id == temp);
              if (i >= 0) {
                _messages[i] = msg;
              } else if (_messages.every((x) => x.id != msg.id)) {
                _messages.add(msg);
              }
            } else if (_messages.every((x) => x.id != msg.id)) {
              _messages.add(msg); // sent from another device
            }
          });
          _scrollToBottomSoon();
        }
        break;

      case 'delivered':
        if (m['user_id'] == _peer) {
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              final x = _messages[i];
              if (x.senderId == _myId && x.status == 'sent') {
                _messages[i] = x.copyWith(status: 'delivered');
              }
            }
          });
        }
        break;

      case 'read_receipt':
        if (m['reader_id'] == _peer) {
          final ids = (m['message_ids'] as List?)
              ?.map((e) => e.toString())
              .toSet();
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              final x = _messages[i];
              final match = ids == null || ids.contains(x.id);
              if (x.senderId == _myId && match && x.status != 'read') {
                _messages[i] = x.copyWith(status: 'read');
              }
            }
          });
        }
        break;

      case 'typing':
        if (m['sender_id'] == _peer) {
          setState(() => _peerTyping = true);
          _typingClear?.cancel();
          _typingClear = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _peerTyping = false);
          });
        }
        break;

      case 'presence':
        if (m['user_id'] == _peer) {
          setState(() => _peerOnline = m['online'] == true);
        }
        break;
    }
  }

  void _send() {
    final text = _input.text.trim();
    final me = _myId;
    if (text.isEmpty || me == null) return;
    final temp = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _messages.add(ChatMessage(
        id: temp,
        senderId: me,
        receiverId: _peer,
        text: text,
        status: 'sending',
        propertyId: widget.property?.id,
        createdAt: DateTime.now(),
      ));
      _pending.add(temp);
      _input.clear();
    });
    _socket.sendMessage(
      receiverId: _peer,
      message: text,
      propertyId: widget.property?.id,
    );
    _scrollToBottomSoon();
  }

  void _onType(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inMilliseconds > 1800) {
      _lastTypingSent = now;
      _socket.sendTyping(_peer);
    }
  }

  void _refreshBadges() {
    ref.invalidate(chatUnreadProvider);
    ref.invalidate(conversationsProvider);
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _reconnected?.cancel();
    _typingClear?.cancel();
    _input.dispose();
    _scroll.dispose();
    _refreshBadges();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1FB),
      appBar: _appBar(),
      body: Column(
        children: [
          if (widget.property != null) _propertyBanner(widget.property!),
          Expanded(child: _body()),
          _composer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final phone = _partner?.phone;
    final subtitle = _peerTyping
        ? 'typing…'
        : (_peerOnline ? 'Online' : 'Offline');
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            backgroundImage: (_avatar != null && _avatar!.isNotEmpty)
                ? NetworkImage(_avatar!)
                : null,
            child: (_avatar == null || _avatar!.isEmpty)
                ? Text(_title.isNotEmpty ? _title[0].toUpperCase() : 'U',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 15.5, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _peerTyping || _peerOnline
                            ? Colors.white
                            : Colors.white70,
                        fontStyle:
                            _peerTyping ? FontStyle.italic : FontStyle.normal)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (phone != null && phone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => launchUrl(Uri.parse('tel:$phone')),
          ),
      ],
    );
  }

  Widget _body() {
    if (_noAuth) {
      return _hint(Icons.lock_outline_rounded, 'Sign in to send messages',
          'You need to be signed in to chat with owners and buyers.');
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return _hint(Icons.forum_outlined, 'Say hello 👋',
          'This is the start of your conversation.');
    }
    // Flatten to chronological rows with day separators.
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final m in _messages) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || d != lastDay) {
        rows.add(_dayChip(d));
        lastDay = d;
      }
      rows.add(_bubble(m));
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: rows,
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.senderId == _myId;
    final bg = mine ? AppColors.primary : Colors.white;
    final fg = mine ? Colors.white : AppColors.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          boxShadow: mine
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text,
                style: GoogleFonts.poppins(fontSize: 13.5, color: fg, height: 1.3)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_time(m.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: mine ? Colors.white70 : AppColors.inkSoft)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  _tick(m.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tick(String status) {
    switch (status) {
      case 'sending':
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
      case 'read':
        return const Icon(Icons.done_all, size: 15, color: Color(0xFF7FE0FF));
      case 'delivered':
        return const Icon(Icons.done_all, size: 15, color: Colors.white70);
      default: // sent
        return const Icon(Icons.check, size: 15, color: Colors.white70);
    }
  }

  Widget _dayChip(DateTime d) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(_dayLabel(d),
            style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft)),
      ),
    );
  }

  Widget _propertyBanner(ChatProperty p) {
    return InkWell(
      onTap: () => context.push('/property/${p.id}'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.image.isNotEmpty
                  ? Image.network(p.image,
                      width: 42, height: 42, fit: BoxFit.cover)
                  : Container(
                      width: 42,
                      height: 42,
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.home_rounded,
                          color: AppColors.primary, size: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title.isNotEmpty ? p.title : 'Property',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  if (p.location.isNotEmpty)
                    Text(p.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F1FB),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _input,
                  onChanged: _onType,
                  enabled: !_noAuth,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.poppins(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13.5, color: AppColors.inkSoft),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _noAuth ? null : _send,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(IconData icon, String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  // ---- formatting -------------------------------------------------------
  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
