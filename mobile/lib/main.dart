import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Android displays the notification from the tray automatically; no work here.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase is only initialized when keys are provided via --dart-define-from-file.
  // See mobile/env.example.json.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  // Firebase (FCM push) is Android-only here; guarded so web/dev without a
  // google-services.json still runs.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (_) {}
  }

  runApp(const ProviderScope(child: RealEstateApp()));
}
