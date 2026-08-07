import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/repo_fallback.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClientProvider)),
);

/// Auth (OTP + Google) always goes through Supabase Auth directly — it issues
/// the JWT that the FastAPI backend then verifies. Profile reads are API-first
/// with a Supabase fallback.
class AuthRepository {
  AuthRepository(this._api);
  final Dio _api;

  SupabaseClient get _client => Supabase.instance.client;

  /// Send a 6-digit OTP to an E.164 phone number, e.g. +919876543210.
  Future<void> sendPhoneOtp(String phoneE164) {
    return _client.auth.signInWithOtp(phone: phoneE164);
  }

  /// Verify the OTP. On success a session (JWT) is created.
  Future<AuthResponse> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: phoneE164,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Google sign-in. Requires the Google provider + a deep-link redirect
  /// configured in Supabase (we'll finish this wiring when you enable it).
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  /// Whether the user finished onboarding — decides routing after login.
  Future<bool> hasCompletedOnboarding() {
    return apiOrDirect<bool>(
      () async {
        final res = await _api.get('/me');
        final profile = (res.data as Map)['profile'] as Map?;
        return (profile?['onboarding_completed'] as bool?) ?? false;
      },
      () async {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) return false;
        final row = await _client
            .from('profiles_home')
            .select('onboarding_completed')
            .eq('id', uid)
            .maybeSingle();
        return (row?['onboarding_completed'] as bool?) ?? false;
      },
    );
  }

  Session? get currentSession => _client.auth.currentSession;
}
