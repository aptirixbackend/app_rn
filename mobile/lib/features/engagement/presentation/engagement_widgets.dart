import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../property/data/property_view.dart';
import '../../property/presentation/widgets/property_card.dart';

String timeAgo(Object? iso) {
  final dt = DateTime.tryParse(iso?.toString() ?? '');
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}

Widget emptyState(String text, IconData icon) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppColors.inkSoft),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );

Widget listTopBar(BuildContext context, String title, String subtitle) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );

/// A tappable property card used by Saved / Enquiries / Visits lists.
/// Delegates to the shared [PropertyCard] so every list uses the same
/// top-image layout; [footer] carries the list-specific status line.
Widget propertyRowCard(
  BuildContext context,
  PropertyView v, {
  String? footer,
  IconData footerIcon = Icons.info_outline_rounded,
  Color? footerColor,
}) {
  return PropertyCard(
    v,
    footer: footer,
    footerIcon: footerIcon,
    footerColor: footerColor,
  );
}
