/// App configuration, injected at build/run time via:
///   flutter run --dart-define-from-file=env.json
///
/// Copy env.example.json to env.json and fill in your values (env.json is gitignored).
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True only when both Supabase keys are provided (live mode). When false the
  /// app runs in preview mode (auth screens are navigable without a backend).
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// FastAPI backend. Default points to the host machine from the Android emulator.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
