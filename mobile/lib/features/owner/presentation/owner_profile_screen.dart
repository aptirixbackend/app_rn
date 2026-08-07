import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';
import '../../property/presentation/widgets/property_card.dart';

/// Public profile for a property owner — their details plus every property
/// they have listed. Opened from the owner card on the detail page.
class OwnerProfileScreen extends ConsumerWidget {
  const OwnerProfileScreen({super.key, required this.ownerId, this.ownerName});

  final String ownerId;
  final String? ownerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerListingsProvider(ownerId));
    final name = (ownerName == null || ownerName!.isEmpty)
        ? 'Property Owner'
        : ownerName!.replaceAll(RegExp(r'\s*\(.*\)$'), '');
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Could not load this owner.\n$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: AppColors.inkSoft)),
                ),
                data: (rows) {
                  final listings = rows.map(PropertyView.new).toList();
                  return ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    children: [
                      _header(name, listings.length),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Text(
                            '${listings.length} '
                            '${listings.length == 1 ? 'Property' : 'Properties'} listed',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (listings.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('This owner has no active listings.',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: AppColors.inkSoft)),
                          ),
                        ),
                      for (final v in listings) PropertyCard(v),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
        child: Row(
          children: [
            IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                icon: const Icon(Icons.arrow_back_rounded)),
            Text('Owner Profile',
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _header(String name, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primarySoft,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'O',
                    style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.prefGreenBg,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 11, color: AppColors.prefGreen),
                              const SizedBox(width: 3),
                              Text('Verified',
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.prefGreen)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: Color(0xFFF5A623)),
                        const SizedBox(width: 3),
                        Text('4.8  ·  Property Owner',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('$count', 'Listings'),
              _divider(),
              _stat('4.8', 'Rating'),
              _divider(),
              _stat('100%', 'Verified'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.inkSoft)),
          ],
        ),
      );
}
