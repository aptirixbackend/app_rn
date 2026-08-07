import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../engagement/data/engagement_repository.dart';
import '../../data/property_view.dart';

/// The app's standard listing card: full-width, image on top, details below.
/// Shared by Search, Saved, Enquiries and Visits so every list looks the same.
/// The heart toggles the favorite for real.
class PropertyCard extends ConsumerWidget {
  const PropertyCard(
    this.v, {
    super.key,
    this.footer,
    this.footerIcon = Icons.info_outline_rounded,
    this.footerColor,
    this.showAmenities = true,
    this.showNegotiable = true,
  });

  final PropertyView v;

  /// Optional status line under the card (e.g. "Enquiry sent", "Visit on …").
  final String? footer;
  final IconData footerIcon;
  final Color? footerColor;
  final bool showAmenities;
  final bool showNegotiable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs =
        ref.watch(favoriteIdsProvider).asData?.value ?? const <String>{};
    final isFav = favs.contains(v.id);
    final shown = v.amenities.take(3).toList();
    final more = v.amenities.length - shown.length;
    final negotiable =
        showNegotiable && (v.purpose == 'rent' || v.purpose == 'sell');

    Future<void> toggleFav() async {
      await ref.read(engagementRepositoryProvider).toggleFavorite(v.id);
      ref
        ..invalidate(favoriteIdsProvider)
        ..invalidate(savedPropertiesProvider)
        ..invalidate(saveCountsProvider);
    }

    return GestureDetector(
      onTap: () => context.push('/property/${v.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- top image ----------------------------------------------
            SizedBox(
              height: 176,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: v.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.home_rounded,
                            color: AppColors.primary, size: 34)),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: v.badgeColor,
                          borderRadius: BorderRadius.circular(7)),
                      child: Text(v.badge,
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: GestureDetector(
                      onTap: toggleFav,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 5),
                          ],
                        ),
                        child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: isFav ? Colors.red : AppColors.ink),
                      ),
                    ),
                  ),
                  if (v.hasVideo)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Video',
                                style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ---- details ------------------------------------------------
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.inkSoft),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(v.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, color: AppColors.inkSoft)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _spec(Icons.bed_outlined, v.beds),
                      _spec(Icons.bathtub_outlined, v.baths),
                      _spec(Icons.crop_free_rounded, v.area),
                      if (v.furnishing.isNotEmpty)
                        _spec(Icons.weekend_outlined, v.furnishing),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        child: Text(v.priceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: v.priceColor)),
                      ),
                      if (negotiable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.prefGreenBg,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('Negotiable',
                              style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.prefGreen)),
                        ),
                      ],
                    ],
                  ),
                  if (showAmenities && shown.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...shown.map(_amenityPill),
                        if (more > 0) _amenityPill('+$more'),
                      ],
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(footerIcon,
                            size: 15, color: footerColor ?? AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(footer!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: footerColor ?? AppColors.ink)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spec(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkSoft),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.ink)),
        ],
      );

  Widget _amenityPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: AppColors.primary,
                fontWeight: FontWeight.w500)),
      );
}
