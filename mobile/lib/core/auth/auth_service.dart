import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../network/api_client.dart';
import 'auth_config.dart';
import 'mock_auth.dart';
import 'token_store.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(
      ref.read(apiClientProvider),
      ref.read(tokenStoreProvider),
      ref.read(mockAuthProvider),
    ));

/// Backend-owned auth. The FastAPI backend generates the OTP, delivers it over
/// Plivo WhatsApp, verifies it, and returns a session JWT — no Supabase Auth.
/// On success the JWT is persisted (attached to every backend request) and the
/// local session cache is populated so the rest of the app keeps working.
class AuthService {
  AuthService(this._api, this._tokens, this._mock);
  final Dio _api;
  final TokenStore _tokens;
  final MockAuth _mock;

  /// Step 1 — ask the backend to send a code to [phoneE164] (e.g. +919876543210).
  Future<void> requestOtp(String phoneE164) async {
    await _api.post('/auth/request-otp', data: {'phone': phoneE164});
  }

  /// Step 2 — verify the code. Returns whether the user has finished onboarding.
  /// Throws (Dio 401) on a wrong/expired code so the caller can shake the field.
  Future<bool> verifyOtp(String phoneE164, String code) async {
    final res = await _api.post(
      '/auth/verify-otp',
      data: {'phone': phoneE164, 'code': code},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = data['access_token'] as String?;
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    if (token == null || token.isEmpty) {
      throw StateError('No session token returned');
    }
    await _tokens.write(token);
    final onboarded = (user['onboarded'] as bool?) ?? false;
    await _mock.replaceSession(
      userId: user['id']?.toString(),
      phone: user['phone']?.toString() ?? phoneE164,
      name: user['name']?.toString(),
      onboarded: onboarded,
    );
    await _hydrate();
    return onboarded;
  }

  /// Pull the full profile (name / email / avatar / goal) from the backend so
  /// the UI reflects THIS user's DB record, never stale local data.
  Future<void> _hydrate() async {
    try {
      final res = await _api.get('/me');
      final profile = (res.data as Map)['profile'];
      if (profile is! Map) return;
      final p = Map<String, dynamic>.from(profile);
      final full = [p['first_name'], p['last_name']]
          .where((e) => (e ?? '').toString().trim().isNotEmpty)
          .join(' ');
      String? clean(Object? v) =>
          (v ?? '').toString().isEmpty ? null : v.toString();
      await _mock.setProfile(
        name: full.isEmpty ? null : full,
        email: clean(p['email']),
        avatar: clean(p['avatar_url']),
      );
      final goal = (p['primary_goal'] ?? '').toString();
      if (goal.isNotEmpty) await _mock.setGoal(goal);
    } catch (_) {}
  }

  /// Google Sign-In. Gets a Google ID token, exchanges it at the backend for
  /// the app's session JWT, and returns the `user` map (which carries
  /// `needs_phone` and `onboarded`), or null if the user cancelled the picker.
  ///
  /// First-time Google users have no phone yet: we store the token (so the
  /// phone-verify step can call the backend) but do NOT mark the session as
  /// logged-in until the phone is verified via [attachPhone].
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    final gsi = GoogleSignIn(
      serverClientId: googleWebClientId,
      scopes: const ['email', 'profile'],
    );
    await gsi.signOut(); // always show the account picker
    final account = await gsi.signIn();
    if (account == null) return null; // cancelled
    final gAuth = await account.authentication;
    final idToken = gAuth.idToken;
    if (idToken == null) throw StateError('No Google ID token');

    final res = await _api.post('/auth/google', data: {'id_token': idToken});
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = data['access_token'] as String?;
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    if (token == null || token.isEmpty) {
      throw StateError('No session token returned');
    }
    await _tokens.write(token);
    final needsPhone = user['needs_phone'] == true;
    // Replace the whole session so a previous account's data is wiped. Don't
    // mark "logged in" until the phone is verified for first-time Google users.
    await _mock.replaceSession(
      userId: user['id']?.toString(),
      phone: user['phone']?.toString(),
      name: user['name']?.toString(),
      email: user['email']?.toString(),
      avatar: user['avatar']?.toString(),
      onboarded: (user['onboarded'] as bool?) ?? false,
      loggedIn: !needsPhone,
    );
    return user;
  }

  /// Verify + attach a phone to the signed-in (Google) user, then complete the
  /// session. Returns whether onboarding is done. Throws (Dio 401/409) on a bad
  /// code or an already-registered number.
  Future<bool> attachPhone(String phoneE164, String code) async {
    final res = await _api
        .post('/auth/attach-phone', data: {'phone': phoneE164, 'code': code});
    final data = Map<String, dynamic>.from(res.data as Map);
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    final onboarded = (user['onboarded'] as bool?) ?? false;
    await _mock.replaceSession(
      userId: user['id']?.toString(),
      phone: user['phone']?.toString() ?? phoneE164,
      name: user['name']?.toString(),
      email: user['email']?.toString(),
      onboarded: onboarded,
    );
    await _hydrate();
    return onboarded;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _tokens.write(null);
    await _mock.logout();
  }
}
