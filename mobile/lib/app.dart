import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_background.dart';

/// Lets horizontal lists be dragged with a mouse/trackpad too (web & desktop),
/// not just touch — otherwise category rows feel "stuck" in the browser.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class RealEstateApp extends ConsumerWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'RentoRent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: AppScrollBehavior(),
      routerConfig: router,
      // Paint the subtle branded canvas behind every route once. Screens with a
      // transparent Scaffold reveal it; solid-white screens sit on top.
      builder: (context, child) =>
          AppBackground(child: child ?? const SizedBox.shrink()),
    );
  }
}
