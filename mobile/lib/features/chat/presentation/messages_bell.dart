import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';

/// Chat icon with a live unread-message badge; taps through to /messages.
class MessagesBell extends ConsumerWidget {
  const MessagesBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(chatUnreadProvider).asData?.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/messages'),
          icon: const Icon(Icons.chat_bubble_outline_rounded,
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
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
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
