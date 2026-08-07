import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/notifications/notif_read_store.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) => EngagementRepository(ref.read(mockAuthProvider)),
);

/// Favorites, leads (enquiries) and site visits. Persists to Supabase directly
/// (dev-permissive RLS), keyed by the local mock user id. Moves behind FastAPI +
/// real auth later.
class EngagementRepository {
  EngagementRepository(this._auth);
  final MockAuth _auth;

  SupabaseClient get _c => Supabase.instance.client;

  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ---- favorites ---------------------------------------------------------
  Future<Set<String>> favoriteIds() async {
    final uid = await _auth.userId();
    final rows =
        await _c.from('favorites_home').select('property_id').eq('user_id', uid);
    return _rows(rows).map((e) => e['property_id'].toString()).toSet();
  }

  /// Toggle favorite; returns true if it is now saved.
  Future<bool> toggleFavorite(String propertyId) async {
    final uid = await _auth.userId();
    final existing = await _c
        .from('favorites_home')
        .select('id')
        .eq('user_id', uid)
        .eq('property_id', propertyId)
        .maybeSingle();
    if (existing != null) {
      await _c.from('favorites_home').delete().eq('id', existing['id']);
      return false;
    }
    await _c
        .from('favorites_home')
        .insert({'user_id': uid, 'property_id': propertyId});
    return true;
  }

  Future<List<Map<String, dynamic>>> savedProperties() async {
    final uid = await _auth.userId();
    final rows = await _c
        .from('favorites_home')
        .select('properties_home(*)')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return _rows(rows)
        .map((e) => e['properties_home'])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ---- leads / enquiries -------------------------------------------------
  /// Create a lead, **de-duplicated**: one enquiry per (property, user) no
  /// matter how many times they tap Contact/WhatsApp/Message; bookings are
  /// tracked separately (one booking request per property). Returns true if a
  /// new lead was created, false if one already existed.
  Future<bool> createLead(
    String propertyId,
    String? ownerId, {
    String kind = 'enquiry',
    String? message,
  }) async {
    final uid = await _auth.userId();
    final isBooking = kind == 'booking';
    final base = _c
        .from('leads_home')
        .select('id')
        .eq('property_id', propertyId)
        .eq('customer_id', uid);
    final existing = isBooking
        ? await base.eq('kind', 'booking').limit(1)
        : await base.neq('kind', 'booking').limit(1);
    if ((existing as List).isNotEmpty) return false;
    await _c.from('leads_home').insert({
      'property_id': propertyId,
      'owner_id': ownerId,
      'customer_id': uid,
      'customer_name': (await _auth.name()) ?? 'Guest User',
      'customer_phone': (await _auth.phone()) ?? '',
      'kind': kind,
      'message': message,
    });
    return true;
  }

  /// The current user's own enquiries (customer view).
  Future<List<Map<String, dynamic>>> myEnquiries() async {
    final uid = await _auth.userId();
    final rows = await _c
        .from('leads_home')
        .select('*, properties_home(*)')
        .eq('customer_id', uid)
        .order('created_at', ascending: false);
    return _rows(rows);
  }

  /// Leads for the owner (My Leads). Demo: all leads (single-owner dataset).
  Future<List<Map<String, dynamic>>> ownerLeads() async {
    final rows = await _c
        .from('leads_home')
        .select('*, properties_home(*)')
        .order('created_at', ascending: false);
    return _rows(rows);
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    await _c.from('leads_home').update({'status': status}).eq('id', leadId);
  }

  Future<void> updateVisitStatus(String visitId, String status) async {
    await _c.from('visits_home').update({'status': status}).eq('id', visitId);
  }

  // ---- activity tracking -------------------------------------------------
  /// Fire-and-forget event log (views, detail clicks, searches, …). Powers
  /// future recommendations and owner-facing insights. Never throws.
  Future<void> track(
    String event, {
    String? propertyId,
    String? ownerId,
    Map<String, dynamic>? meta,
  }) async {
    try {
      await _c.from('activity_home').insert({
        'user_id': await _auth.userId(),
        'event_type': event,
        'property_id': propertyId,
        'owner_id': ownerId,
        'meta': meta ?? const {},
      });
    } catch (_) {
      // tracking must never break the UX
    }
  }

  // ---- visits ------------------------------------------------------------
  /// Request a site visit, **de-duplicated**: one active request per
  /// (property, user). Returns true if created, false if one already exists.
  Future<bool> createVisit(
    String propertyId,
    String? ownerId, {
    DateTime? date,
    String? slot,
  }) async {
    final uid = await _auth.userId();
    final existing = await _c
        .from('visits_home')
        .select('id')
        .eq('property_id', propertyId)
        .eq('customer_id', uid)
        .limit(1);
    if ((existing as List).isNotEmpty) return false;
    await _c.from('visits_home').insert({
      'property_id': propertyId,
      'owner_id': ownerId,
      'customer_id': uid,
      'customer_name': (await _auth.name()) ?? 'Guest User',
      'customer_phone': (await _auth.phone()) ?? '',
      'scheduled_for': date?.toIso8601String().split('T').first,
      'slot': slot,
    });
    return true;
  }

  Future<List<Map<String, dynamic>>> myVisits() async {
    final uid = await _auth.userId();
    final rows = await _c
        .from('visits_home')
        .select('*, properties_home(*)')
        .eq('customer_id', uid)
        .order('created_at', ascending: false);
    return _rows(rows);
  }

  /// Visit requests for the owner (My Leads / notifications). Demo: all visits.
  Future<List<Map<String, dynamic>>> ownerVisits() async {
    final rows = await _c
        .from('visits_home')
        .select('*, properties_home(*)')
        .order('created_at', ascending: false);
    return _rows(rows);
  }

  /// Save (favorite) counts per property, across all users.
  Future<Map<String, int>> saveCounts() async {
    final rows = await _c.from('favorites_home').select('property_id');
    final m = <String, int>{};
    for (final r in _rows(rows)) {
      final id = (r['property_id'] ?? '').toString();
      if (id.isNotEmpty) m[id] = (m[id] ?? 0) + 1;
    }
    return m;
  }
}

// ---- providers -----------------------------------------------------------
final favoriteIdsProvider =
    FutureProvider<Set<String>>((ref) => ref.read(engagementRepositoryProvider).favoriteIds());

final savedPropertiesProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.read(engagementRepositoryProvider).savedProperties());

final myEnquiriesProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.read(engagementRepositoryProvider).myEnquiries());

final myVisitsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.read(engagementRepositoryProvider).myVisits());

/// Property ids the current user has already enquired on (non-booking) — used
/// to switch detail-page Contact buttons to an "Enquiry Sent" state.
final myEnquiredIdsProvider = FutureProvider<Set<String>>((ref) async {
  final leads = await ref.watch(myEnquiriesProvider.future);
  return leads
      .where((l) => (l['kind'] ?? '') != 'booking')
      .map((l) => (l['property_id'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet();
});

/// Property ids the current user has already requested a visit for.
final myVisitedIdsProvider = FutureProvider<Set<String>>((ref) async {
  final visits = await ref.watch(myVisitsProvider.future);
  return visits
      .map((v) => (v['property_id'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet();
});

final ownerLeadsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.read(engagementRepositoryProvider).ownerLeads());

final ownerVisitsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.read(engagementRepositoryProvider).ownerVisits());

final saveCountsProvider = FutureProvider<Map<String, int>>(
    (ref) => ref.read(engagementRepositoryProvider).saveCounts());

/// Unread notification count for the bell badge (role-aware) — only activity
/// newer than the last time the user opened the Notifications page.
final notificationCountProvider = FutureProvider<int>((ref) async {
  final lastRead = ref.watch(notifLastReadProvider);
  final goal = await ref.read(mockAuthProvider).goal();
  final repo = ref.read(engagementRepositoryProvider);
  final items = <Map<String, dynamic>>[];
  if (goal == 'post') {
    items
      ..addAll(await repo.ownerLeads())
      ..addAll(await repo.ownerVisits());
  } else {
    items
      ..addAll(await repo.myEnquiries())
      ..addAll(await repo.myVisits());
  }
  return items.where((x) {
    final t = DateTime.tryParse((x['created_at'] ?? '').toString());
    return t != null && t.millisecondsSinceEpoch > lastRead;
  }).length;
});
