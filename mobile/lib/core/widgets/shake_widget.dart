import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] and plays a quick horizontal shake each time [trigger]
/// changes value. Used to signal invalid input (e.g. a wrong OTP).
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.trigger, required this.child});

  /// Change this value (e.g. increment a counter) to fire a shake.
  final int trigger;
  final Widget child;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void didUpdateWidget(ShakeWidget old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Decaying oscillation → a few sharp shakes that settle back to centre.
        final dx = math.sin(t * math.pi * 5) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
