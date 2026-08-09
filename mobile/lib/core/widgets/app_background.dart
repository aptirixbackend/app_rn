import 'package:flutter/material.dart';

/// A soft branded canvas used behind every screen — an all-but-white
/// lavender-grey instead of raw white, so pages read as calm and intentional
/// while white cards, sheets and bars still stand out on top.
///
/// Wired once in [MaterialApp.router]'s `builder`, so it sits behind the whole
/// navigator. Pages with a transparent Scaffold reveal it; pages that need
/// solid white (forms, media) simply keep their own background on top.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  /// The base tint — matches the app's card/border family, just a hair off white.
  static const base = Color(0xFFF6F6FC);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: base),
      child: child,
    );
  }
}
