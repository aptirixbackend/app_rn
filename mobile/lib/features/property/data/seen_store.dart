import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'property_view.dart';

const _kSeen = 'seen_property_ids';

/// Ids of properties the user has already opened. Used to push already-viewed
/// listings to the end of "Recommended" so fresh ones surface first.
class SeenIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = (p.getStringList(_kSeen) ?? const []).toSet();
  }

  Future<void> markSeen(String id) async {
    if (id.isEmpty || state.contains(id)) return;
    state = {...state, id};
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSeen, state.toList());
  }
}

final seenIdsProvider =
    NotifierProvider<SeenIdsNotifier, Set<String>>(SeenIdsNotifier.new);

/// Stable reorder: not-yet-seen listings first, already-seen ones moved to the
/// end (still shown, so the list never empties just because everything's seen).
List<PropertyView> seenLast(List<PropertyView> list, Set<String> seen) {
  if (seen.isEmpty) return list;
  final fresh = <PropertyView>[];
  final old = <PropertyView>[];
  for (final v in list) {
    (seen.contains(v.id) ? old : fresh).add(v);
  }
  return [...fresh, ...old];
}
