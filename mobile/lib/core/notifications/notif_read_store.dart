import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastRead = 'notif_last_read_millis';

/// Timestamp (ms since epoch) the user last opened the Notifications page.
/// The bell badge only counts activity newer than this — so opening the page
/// clears the badge, and it treats already-seen notifications as read.
class NotifRead extends Notifier<int> {
  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getInt(_kLastRead) ?? 0;
  }

  Future<void> markReadNow() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = now;
    (await SharedPreferences.getInstance()).setInt(_kLastRead, now);
  }
}

final notifLastReadProvider =
    NotifierProvider<NotifRead, int>(NotifRead.new);
