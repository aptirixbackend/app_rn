import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Real Supabase-backed auth, used only when [useRealAuth] is on.
///
/// Phone OTP is **generated and verified by Supabase**; delivery is handled by
/// the Plivo "Send OTP" auth hook (WhatsApp with SMS fallback) — see the
/// `supabase/functions/send-otp` edge function. Google uses the OAuth redirect
/// flow, which works on both web and mobile with a single web client ID.
class AuthService {
  SupabaseClient get _c => Supabase.instance.client;

  Session? get session => _c.auth.currentSession;
  Stream<AuthState> get onAuthChange => _c.auth.onAuthStateChange;

  /// Ask Supabase to send a login code to [phoneE164] (e.g. `+919876543210`).
  Future<void> sendPhoneOtp(String phoneE164) =>
      _c.auth.signInWithOtp(phone: phoneE164);

  /// Verify the 6-digit code the user typed.
  Future<AuthResponse> verifyPhoneOtp(String phoneE164, String token) =>
      _c.auth.verifyOTP(type: OtpType.sms, phone: phoneE164, token: token);

  /// Google OAuth. On web this redirects the current tab; on mobile it opens a
  /// browser tab and returns via the [redirectTo] deep link. Completion is
  /// picked up by the router's auth-state listener.
  Future<bool> signInWithGoogle() => _c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            kIsWeb ? null : 'com.realestate.homevista://login-callback',
      );

  Future<void> signOut() => _c.auth.signOut();
}
