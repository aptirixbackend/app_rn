import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/repo_fallback.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.read(apiClientProvider)),
);

/// API-first (FastAPI) with a Supabase fallback. See [apiOrDirect].
class OnboardingRepository {
  OnboardingRepository(this._api);
  final Dio _api;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Save the user's primary goal: 'post' or 'search'.
  Future<void> setPrimaryGoal(String goal) {
    return apiOrDirect(
      () async => _api.post('/onboarding/goal', data: {'goal': goal}),
      () async {
        final uid = _uid;
        if (uid == null) return;
        await _client
            .from('profiles_home')
            .update({'primary_goal': goal}).eq('id', uid);
      },
    );
  }

  /// Save the "Tell us about yourself" step and mark onboarding complete.
  Future<void> saveAboutYou({
    required String firstName,
    required String lastName,
    DateTime? dob,
    String? email,
    required List<String> preferences,
  }) {
    final dobStr = dob?.toIso8601String().split('T').first;
    return apiOrDirect(
      () async => _api.post('/onboarding', data: {
        'first_name': firstName,
        'last_name': lastName,
        'dob': dobStr,
        'email': email,
        'preferences': preferences,
      }),
      () async {
        final uid = _uid;
        if (uid == null) return;
        await _client.from('profiles_home').update({
          'first_name': firstName,
          'last_name': lastName,
          'dob': dobStr,
          'email': email,
          'onboarding_completed': true,
        }).eq('id', uid);
        if (preferences.isNotEmpty) {
          final rows = preferences
              .map((p) => {'user_id': uid, 'preference': p})
              .toList();
          await _client
              .from('user_preferences_home')
              .upsert(rows, onConflict: 'user_id,preference');
        }
      },
    );
  }
}
