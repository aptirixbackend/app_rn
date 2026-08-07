import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the backend-issued session JWT and keeps it in memory so the Dio
/// interceptor can attach it on every request without an async round-trip.
class TokenStore {
  static const _k = 'auth_token';
  String? _cached;
  bool _loaded = false;

  Future<String?> read() async {
    if (_loaded) return _cached;
    _cached = (await SharedPreferences.getInstance()).getString(_k);
    _loaded = true;
    return _cached;
  }

  String? get cached => _cached;
  bool get isLoggedIn => (_cached ?? '').isNotEmpty;

  Future<void> write(String? token) async {
    _cached = token;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_k);
    } else {
      await p.setString(_k, token);
    }
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
