import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Dio client for the FastAPI backend. Automatically attaches the current
/// Supabase access token so protected endpoints (/me, /properties, ...) work.
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
      onRequest: (options, handler) {
        String? token;
        try {
          token = Supabase.instance.client.auth.currentSession?.accessToken;
        } catch (_) {
          token = null; // Supabase not initialized yet
        }
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
