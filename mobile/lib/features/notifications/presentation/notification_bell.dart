import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../engagement/data/engagement_repository.dart';

/// Bell icon with a live activity-count badge; taps through to /notifications.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationCountProvider).asData?.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded,
              color: AppColors.ink),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 8,
                      height: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}
