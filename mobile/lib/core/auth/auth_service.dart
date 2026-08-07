import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
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
    await _mock.setSession(
      userId: user['id']?.toString(),
      phone: user['phone']?.toString() ?? phoneE164,
      name: user['name']?.toString(),
    );
    return (user['onboarded'] as bool?) ?? false;
  }

  Future<void> signOut() async {
    await _tokens.write(null);
    await _mock.logout();
  }
}
