import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/location/city_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/repo_fallback.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>(
  (ref) => PropertyRepository(ref.read(apiClientProvider)),
);

/// Published listings feed, shared by Home ("Recommended") and Search.
final publishedPropertiesProvider =
    FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(propertyRepositoryProvider).getPublishedProperties(),
);

/// A single listing by id, used by the property detail page.
final propertyByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, id) => ref.read(propertyRepositoryProvider).getPropertyById(id),
);

/// The current owner's listings (My Properties screen).
final myPropertiesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(propertyRepositoryProvider).myProperties(),
);

/// All published listings for a given owner id (owner profile page).
final ownerListingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, ownerId) =>
      ref.read(propertyRepositoryProvider).propertiesByOwner(ownerId),
);

/// The published feed scoped to the selected city — used by all searcher-facing
/// screens (Home, Search, Map, segment landing). Same AsyncValue shape as
/// [publishedPropertiesProvider] so it's a drop-in swap.
final visiblePropertiesProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final city = ref.watch(selectedCityProvider).toLowerCase();
  return ref.watch(publishedPropertiesProvider).whenData((rows) => rows
      .where((r) => (r['city'] ?? '').toString().toLowerCase() == city)
      .toList());
});

/// API-first (FastAPI) with a Supabase fallback. See [apiOrDirect].
/// Media uploads always go straight to Supabase Storage.
class PropertyRepository {
  PropertyRepository(this._api);
  final Dio _api;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Demo owner (seed user "Sneha Reddy") — used as owner_id for owner-posted
  /// listings while auth is mocked (mock user ids aren't valid uuids). The real
  /// Supabase auth uid takes over automatically once auth is wired in.
  static const _demoOwnerId = 'c508f4a5-272c-4aaa-bf3d-b8c23a3e26e1';
  String get _ownerId => _uid ?? _demoOwnerId;

  static const _bucket = 'property-media';

  /// Step: property basics -> returns the new draft's id.
  Future<String?> createDraftBasics({
    required String propertyType,
    required String purpose,
    String? city,
    String? area,
    num? latitude,
    num? longitude,
    String? bhk,
    int? bathrooms,
    num? carpetArea,
    String? furnishing,
    int? floorNumber,
    int? totalFloors,
    String? propertyAge,
    String? facing,
    DateTime? availableFrom,
    Map<String, dynamic>? attributes,
  }) {
    final body = <String, dynamic>{
      'property_type': propertyType,
      'purpose': purpose,
      'city': city,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'bhk': bhk,
      'bathrooms': bathrooms,
      'carpet_area': carpetArea,
      'furnishing': furnishing,
      'floor_number': floorNumber,
      'total_floors': totalFloors,
      'property_age': propertyAge,
      'facing': facing,
      'available_from': availableFrom?.toIso8601String().split('T').first,
      'attributes':
          (attributes != null && attributes.isNotEmpty) ? attributes : null,
    }..removeWhere((_, v) => v == null);

    return apiOrDirect<String?>(
      () async {
        final res = await _api.post('/properties', data: body);
        return (res.data as Map)['id'] as String?;
      },
      () async {
        final row = await _client
            .from('properties_home')
            .insert({...body, 'owner_id': _ownerId, 'status': 'draft'})
            .select('id')
            .single();
        return row['id'] as String?;
      },
    );
  }

  /// Step: amenities & features.
  Future<void> saveAmenities(
    String propertyId, {
    required List<String> amenities,
    required List<String> additionalFeatures,
    String? highlights,
  }) {
    final body = <String, dynamic>{
      'amenities': amenities,
      'additional_features': additionalFeatures,
    };
    if (highlights != null) body['highlights'] = highlights;
    return apiOrDirect(
      () async => _api.patch('/properties/$propertyId', data: body),
      () async =>
          _client.from('properties_home').update(body).eq('id', propertyId),
    );
  }

  /// Upload an image to Storage and return its public URL.
  /// Requires a public `property-media` bucket. (Always direct to Storage.)
  Future<String?> uploadMedia(
    Uint8List bytes,
    String fileName, {
    String contentType = 'image/jpeg',
  }) async {
    final path = '$_ownerId/$fileName';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  /// Step: photos & media.
  Future<void> saveMedia(
    String propertyId, {
    String? coverUrl,
    List<String>? photoUrls,
    String? videoUrl,
    String? floorPlanUrl,
  }) {
    final body = <String, dynamic>{};
    if (coverUrl != null) body['cover_image_url'] = coverUrl;
    if (photoUrls != null) body['photo_urls'] = photoUrls;
    if (videoUrl != null) body['video_url'] = videoUrl;
    if (floorPlanUrl != null) body['floor_plan_url'] = floorPlanUrl;
    if (body.isEmpty) return Future.value();
    return apiOrDirect(
      () async => _api.patch('/properties/$propertyId', data: body),
      () async =>
          _client.from('properties_home').update(body).eq('id', propertyId),
    );
  }

  /// The most recent draft for the current user (used by Review).
  Future<Map<String, dynamic>?> getLatestDraft() {
    return apiOrDirect<Map<String, dynamic>?>(
      () async {
        final res = await _api.get('/properties/mine/latest-draft');
        final data = res.data;
        return data == null ? null : Map<String, dynamic>.from(data as Map);
      },
      () async {
        return _client
            .from('properties_home')
            .select()
            .eq('owner_id', _ownerId)
            .eq('status', 'draft')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      },
    );
  }

  Future<Map<String, dynamic>?> getMyProfile() {
    return apiOrDirect<Map<String, dynamic>?>(
      () async {
        final res = await _api.get('/me');
        final profile = (res.data as Map)['profile'];
        return profile == null
            ? null
            : Map<String, dynamic>.from(profile as Map);
      },
      () async {
        return _client
            .from('profiles_home')
            .select()
            .eq('id', _ownerId)
            .maybeSingle();
      },
    );
  }

  /// Update the current user's profile (avatar, name, …). Goes through the
  /// backend (service key) since profiles_home isn't anon-writable.
  Future<void> updateMyProfile(Map<String, dynamic> fields) {
    final body = {...fields}..removeWhere((_, v) => v == null);
    if (body.isEmpty) return Future.value();
    return apiOrDirect(
      () async => _api.patch('/me', data: body),
      () async =>
          _client.from('profiles_home').update(body).eq('id', _ownerId),
    );
  }

  Future<void> publish(String propertyId) {
    return apiOrDirect(
      () async => _api.post('/properties/$propertyId/publish'),
      () async => _client
          .from('properties_home')
          .update({'status': 'published'}).eq('id', propertyId),
    );
  }

  /// Change a listing's status: draft / published / paused / closed. For
  /// 'closed', records the reason (booked/sold/rented) and who it went to.
  Future<void> setStatus(String id, String status,
      {String? closeReason, String? closedTo}) async {
    final body = <String, dynamic>{'status': status};
    if (closeReason != null || (closedTo != null && closedTo.isNotEmpty)) {
      final row = await _client
          .from('properties_home')
          .select('attributes')
          .eq('id', id)
          .maybeSingle();
      final attrs = (row?['attributes'] is Map)
          ? Map<String, dynamic>.from(row!['attributes'] as Map)
          : <String, dynamic>{};
      if (closeReason != null) attrs['closed_reason'] = closeReason;
      if (closedTo != null && closedTo.isNotEmpty) attrs['closed_to'] = closedTo;
      body['attributes'] = attrs;
    }
    await apiOrDirect(
      () async => _api.patch('/properties/$id', data: body),
      () async => _client.from('properties_home').update(body).eq('id', id),
    );
  }

  /// Patch arbitrary editable fields on a listing (Edit Property screen).
  Future<void> updateProperty(String id, Map<String, dynamic> fields) {
    final body = {...fields}..removeWhere((_, v) => v == null);
    if (body.isEmpty) return Future.value();
    return apiOrDirect(
      () async => _api.patch('/properties/$id', data: body),
      () async =>
          _client.from('properties_home').update(body).eq('id', id),
    );
  }

  /// The current owner's listings (My Properties) — all statuses incl. drafts.
  Future<List<Map<String, dynamic>>> myProperties() {
    return apiOrDirect<List<Map<String, dynamic>>>(
      () async {
        final res = await _api.get('/properties/mine');
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      },
      () async {
        final rows = await _client
            .from('properties_home')
            .select()
            .eq('owner_id', _ownerId)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      },
    );
  }

  /// Public feed of published listings (Home + Search). No auth required.
  Future<List<Map<String, dynamic>>> getPublishedProperties({int limit = 200}) {
    return apiOrDirect<List<Map<String, dynamic>>>(
      () async {
        final res =
            await _api.get('/properties', queryParameters: {'limit': limit});
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      },
      () async {
        final rows = await _client
            .from('properties_home')
            .select()
            .eq('status', 'published')
            .order('created_at', ascending: false)
            .limit(limit);
        return (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      },
    );
  }

  /// All published listings for a given owner (owner profile page). Queried
  /// directly so the owner filter is always honoured, backend up or down.
  Future<List<Map<String, dynamic>>> propertiesByOwner(String ownerId) async {
    final rows = await _client
        .from('properties_home')
        .select()
        .eq('owner_id', ownerId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// A single published listing by id (property detail page).
  Future<Map<String, dynamic>?> getPropertyById(String id) {
    return apiOrDirect<Map<String, dynamic>?>(
      () async {
        final res = await _api.get('/properties/$id');
        return res.data == null
            ? null
            : Map<String, dynamic>.from(res.data as Map);
      },
      () async => _client
          .from('properties_home')
          .select()
          .eq('id', id)
          .maybeSingle(),
    );
  }
}
