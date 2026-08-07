import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/mock_auth.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // Design illustrations used across the first screens — warm the image cache
  // during the splash so sign-in / home / posting paint instantly.
  static const _precache = <String>[
    'assets/images/home_signup.png',
    'assets/images/bottom_design.png',
    'assets/images/otp_screen.png',
    'assets/images/tellus_properity.png',
    'assets/images/for_home.png',
    'assets/images/features.png',
    'assets/images/search_home.png',
    'assets/images/location.png',
    'assets/images/photo_upload.png',
    'assets/images/review_page.png',
  ];

  bool _warmed = false;

  @override
  void initState() {
    super.initState();
    // Returning users who already filled their details go straight to Home;
    // everyone else starts at sign-in.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final onboarded = await ref.read(mockAuthProvider).isOnboarded();
      if (mounted) context.go(onboarded ? '/home' : '/sign-in');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmed) return;
    _warmed = true;
    for (final asset in _precache) {
      // Fire-and-forget: fills the global ImageCache before the next route.
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primaryContainer],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.holiday_village_rounded, size: 72, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'HomeVista',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
