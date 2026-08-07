/// API-first with a direct-Supabase fallback.
///
/// Runs [api] (the FastAPI backend) first — this is the same endpoint a future
/// website would call. If it fails for ANY reason (backend not running, network
/// error, 5xx, not yet configured), it falls back to [direct] (Supabase client)
/// so the app keeps working. When the backend is up, the API path wins.
Future<T> apiOrDirect<T>(
  Future<T> Function() api,
  Future<T> Function() direct,
) async {
  try {
    return await api();
  } catch (_) {
    return await direct();
  }
}
