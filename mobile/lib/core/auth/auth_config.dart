/// Master switch for real, backend-owned auth (phone OTP delivered by Plivo
/// WhatsApp and verified by the FastAPI backend, which issues the session JWT).
///
/// While this is `false` the app uses the local mock OTP (`123456`) so the demo
/// works with no backend reachable. Turn it on for production builds with:
///   --dart-define=USE_REAL_AUTH=true
/// (the backend must be deployed and `API_BASE_URL` must point at it).
const bool useRealAuth =
    bool.fromEnvironment('USE_REAL_AUTH', defaultValue: false);
