/// Master switch for real Supabase auth (Google Sign-In + phone OTP delivered
/// by Plivo). While this is `false` the app keeps using the local mock OTP
/// (`123456`) so the demo works with no backend auth configured.
///
/// Turn it on at go-live by building with:
///   --dart-define=USE_REAL_AUTH=true
/// once the Google provider and the Plivo Send-OTP hook are set up in the
/// Supabase dashboard (see docs/auth-setup.md).
const bool useRealAuth =
    bool.fromEnvironment('USE_REAL_AUTH', defaultValue: false);
