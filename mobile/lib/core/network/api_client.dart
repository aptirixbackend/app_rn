import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_store.dart';
import '../config/env.dart';

/// Dio client for the FastAPI backend. Attaches the backend-issued session JWT
/// (from [TokenStore]) so protected endpoints (/auth/session, owner writes, …)
/// work. When there's no token yet, requests go unauthenticated and the backend
/// treats them as the demo owner while the app is still in mock mode.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      // Short so the Supabase fallback kicks in fast when the backend is down.
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final store = ref.read(tokenStoreProvider);
        final token = store.cached ?? await store.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
