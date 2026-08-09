import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../router/app_router.dart';
import '../../features/engagement/data/engagement_repository.dart';

/// Registers this device's FCM token with the backend (so it can push to the
/// signed-in user), refreshes the in-app feed on foreground messages, and
/// opens the right screen when a notification is tapped.
class PushService {
  PushService(this._ref);
  final Ref _ref;
  bool _started = false;

  Future<void> start() async {
    if (kIsWeb || _started) return;
    _started = true;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(); // Android 13+ prompt
      await _register(await fm.getToken());
      fm.onTokenRefresh.listen(_register);

      FirebaseMessaging.onMessage.listen((_) {
        // A push arrived while the app is open — refresh the activity feed.
        _ref
          ..invalidate(notificationCountProvider)
          ..invalidate(ownerLeadsProvider)
          ..invalidate(ownerVisitsProvider)
          ..invalidate(myEnquiriesProvider)
          ..invalidate(myVisitsProvider);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      final initial = await fm.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (_) {
      _started = false; // allow a later retry
    }
  }

  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _ref.read(apiClientProvider).post(
        '/devices',
        data: {'token': token, 'platform': 'android'},
      );
    } catch (_) {}
  }

  void _handleTap(RemoteMessage m) {
    final propId = (m.data['property_id'] ?? '').toString();
    final router = _ref.read(appRouterProvider);
    if (propId.isNotEmpty) {
      router.push('/property/$propId');
    } else {
      router.push('/notifications');
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
