import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../property/data/property_filter.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';
import '../../property/data/seen_store.dart';

/// Per-segment content (hero copy, colours, feature strip, promo banner).
class _SegContent {
  const _SegContent({
    required this.title,
    required this.subtitle,
    required this.heroTitle,
    required this.heroSub,
    required this.heroImage,
    required this.heroGradient,
    required this.heroDark,
    required this.features,
    required this.premiumTitle,
    required this.promoTitle,
    required this.promoSub,
    required this.promoCta,
    required this.promoImage,
    required this.promoGradient,
    required this.promoDark,
    this.typeChipLabel = 'Property Type',
  });

  final String title, subtitle, heroTitle, heroSub, heroImage;
  final List<Color> heroGradient;
  final bool heroDark; // hero uses light text on a dark/coloured panel
  final List<(IconData, String)> features;
  final String premiumTitle;
  final String promoTitle, promoSub, promoCta, promoImage;
  final List<Color> promoGradient;
  final bool promoDark;
  final String typeChipLabel;
}

const _content = <Segment, _SegContent>{
  Segment.rent: _SegContent(
    title: 'Rent',
    subtitle: 'Find your next rental home',
    heroTitle: 'Find the perfect rental home for you',
    heroSub: 'Verified properties with trusted owners',
    heroImage: 'assets/images/rent_page.png',
    heroGradient: [Color(0xFF14795E), Color(0xFF2FA36B)],
    heroDark: true,
    features: [
      (Icons.money_off_rounded, 'No Brokerage'),
      (Icons.verified_user_outlined, 'Verified Properties'),
      (Icons.grid_view_rounded, 'Wide Selection'),
      (Icons.vpn_key_outlined, 'Easy Renting'),
    ],
    premiumTitle: 'Premium Rentals',
    promoTitle: 'Move in stress-free!',
    promoSub: 'Get verified homes with lease support & expert assistance.',
    promoCta: 'Learn More',
    promoImage: 'assets/images/rent_img1.png',
    promoGradient: [Color(0xFFF4ECDD), Color(0xFFF6EFE2)],
    promoDark: false,
  ),
  Segment.buy: _SegContent(
    title: 'Buy',
    subtitle: 'Find your dream home',
    heroTitle: 'Own your dream home today',
    heroSub: 'Curated listings with best deals',
    heroImage: 'assets/images/home_signup.png',
    heroGradient: [Color(0xFF1E293B), Color(0xFF334155)],
    heroDark: true,
    features: [
      (Icons.apartment_rounded, 'Top Builders'),
      (Icons.account_balance_outlined, 'Loans Available'),
      (Icons.home_work_outlined, 'Ready to Move'),
      (Icons.trending_up_rounded, 'High ROI'),
    ],
    premiumTitle: 'Premium Homes',
    promoTitle: 'Home Loan Made Easy',
    promoSub: 'Get the best home loan options with the lowest interest rates.',
    promoCta: 'Check Now',
    promoImage: 'assets/images/flat.png',
    promoGradient: [Color(0xFFE9F4ED), Color(0xFFF0F7F2)],
    promoDark: false,
  ),
  Segment.stay: _SegContent(
    title: 'Stay',
    subtitle: 'Book by the day or month',
    heroTitle: 'Book your perfect stay',
    heroSub: 'Rooms & homes, by the day or the month',
    heroImage: 'assets/images/rent_img1.png',
    heroGradient: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    heroDark: true,
    features: [
      (Icons.event_available_outlined, 'Day or Month'),
      (Icons.flash_on_rounded, 'Instant Book'),
      (Icons.chair_outlined, 'Fully Furnished'),
      (Icons.verified_user_outlined, 'Verified Stays'),
    ],
    premiumTitle: 'Featured Stays',
    promoTitle: 'Long stay, big savings',
    promoSub: 'Book monthly and save up to 30% on nightly rates.',
    promoCta: 'Explore',
    promoImage: 'assets/images/pg_img2.png',
    promoGradient: [Color(0xFFE6F5F3), Color(0xFFF0FAF8)],
    promoDark: false,
  ),
  Segment.pg: _SegContent(
    title: 'PG / Co-living',
    subtitle: 'Comfortable stays, like home',
    heroTitle: 'Comfortable stays that feel like home',
    heroSub: 'PGs & Co-living spaces with all amenities',
    heroImage: 'assets/images/pg_coliving.png',
    heroGradient: [Color(0xFF6D5AE6), Color(0xFF8E7BF2)],
    heroDark: true,
    features: [
      (Icons.chair_outlined, 'Fully Furnished'),
      (Icons.wifi_rounded, 'Wi-Fi Included'),
      (Icons.restaurant_rounded, 'Meals Available'),
      (Icons.event_available_outlined, 'Flexible Tenure'),
    ],
    premiumTitle: 'Top Co-living Spaces',
    promoTitle: 'Special Offers!',
    promoSub: 'Get up to 20% OFF on selected PG & Co-living spaces.',
    promoCta: 'View Offers',
    promoImage: 'assets/images/pg_img2.png',
    promoGradient: [Color(0xFF6D5AE6), Color(0xFF8E7BF2)],
    promoDark: true,
    typeChipLabel: 'For Anyone',
  ),
  Segment.commercial: _SegContent(
    title: 'Commercial',
    subtitle: 'Offices, shops & coworking',
    heroTitle: 'Space that grows your business',
    heroSub: 'Offices, retail & coworking spaces',
    heroImage: 'assets/images/commerial.png',
    heroGradient: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
    heroDark: true,
    features: [
      (Icons.location_city_rounded, 'Prime Locations'),
      (Icons.meeting_room_outlined, 'Ready Offices'),
      (Icons.event_available_outlined, 'Flexible Lease'),
      (Icons.groups_outlined, 'High Footfall'),
    ],
    premiumTitle: 'Premium Spaces',
    promoTitle: 'Grow with the right space',
    promoSub: 'Flexible lease options for teams of every size.',
    promoCta: 'Explore',
    promoImage: 'assets/images/commerial.png',
    promoGradient: [Color(0xFFE8EEFB), Color(0xFFF0F4FC)],
    promoDark: false,
  ),
  Segment.plots: _SegContent(
    title: 'Plots / Land',
    subtitle: 'Build your future',
    heroTitle: 'Find the perfect plot to build on',
    heroSub: 'DTCP-approved, clear-title plots',
    heroImage: 'assets/images/plot.png',
    heroGradient: [Color(0xFF15803D), Color(0xFF22A55B)],
    heroDark: true,
    features: [
      (Icons.description_outlined, 'Clear Title'),
      (Icons.fence_outlined, 'Gated Layout'),
      (Icons.foundation_outlined, 'Ready to Build'),
      (Icons.trending_up_rounded, 'Great Appreciation'),
    ],
    premiumTitle: 'Premium Plots',
    promoTitle: 'Invest in land today',
    promoSub: 'Prime, approved plots with great appreciation potential.',
    promoCta: 'Learn More',
    promoImage: 'assets/images/plot.png',
    promoGradient: [Color(0xFFEAF4EC), Color(0xFFF1F8F2)],
    promoDark: false,
  ),
};

const _localityImages = [
  'assets/images/tellus_properity.png',
  'assets/images/search_home.png',
  'assets/images/for_home.png',
  'assets/images/flat.png',
  'assets/images/location.png',
  'assets/images/review_page.png',
];

class SegmentLandingScreen extends ConsumerWidget {
  const SegmentLandingScreen({super.key, required this.segment});

  final Segment segment;

  static Segment parse(String s) {
    switch (s) {
      case 'buy':
        return Segment.buy;
      case 'stay':
        return Segment.stay;
      case 'pg':
        return Segment.pg;
      case 'commercial':
        return Segment.commercial;
      case 'plots':
        return Segment.plots;
      case 'rent':
      default:
        return Segment.rent;
    }
  }

  PropertyFilter get _filter => PropertyFilter(segment: segment);
  void _toSearch(BuildContext context) =>
      context.push('/search', extra: _filter);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _content[segment]!;
    final async = ref.watch(visiblePropertiesProvider);
    final seen = ref.watch(seenIdsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(context, c),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Could not load listings',
                        style: GoogleFonts.poppins(color: AppColors.inkSoft))),
                data: (rows) {
                  final listings =
                      _filter.apply(rows.map(PropertyView.new).toList());
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _searchRow(context, c),
                      const SizedBox(height: 12),
                      _chips(context, c),
                      const SizedBox(height: 16),
                      _hero(context, c),
                      const SizedBox(height: 18),
                      _features(c),
                      const SizedBox(height: 20),
                      _localities(context, c, listings),
                      const SizedBox(height: 20),
                      _recommended(context, c, seenLast(listings, seen)),
                      const SizedBox(height: 20),
                      _premium(context, c, listings),
                      const SizedBox(height: 20),
                      _promo(context, c),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 'search'),
    );
  }

  // ---- top bar -----------------------------------------------------------
  Widget _topBar(BuildContext context, _SegContent c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                Text(c.subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          IconButton(
              onPressed: () => context.push('/saved'),
              icon: const Icon(Icons.favorite_border_rounded,
                  color: AppColors.ink)),
        ],
      ),
    );
  }

  // ---- search + chips ----------------------------------------------------
  Widget _searchRow(BuildContext context, _SegContent c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _toSearch(context),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.inkSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Search by locality, city or property',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: AppColors.inkSoft)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _toSearch(context),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.tune_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context, _SegContent c) {
    Widget chip(IconData icon, String label, {bool solid = false}) =>
        GestureDetector(
          onTap: () => _toSearch(context),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: solid ? AppColors.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: solid ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: solid ? AppColors.primary : AppColors.inkSoft),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: solid ? AppColors.primary : AppColors.ink)),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: solid ? AppColors.primary : AppColors.inkSoft),
              ],
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip(Icons.location_on_outlined, 'Bengaluru', solid: true),
          chip(Icons.currency_rupee_rounded, 'Budget'),
          chip(Icons.apartment_rounded, c.typeChipLabel),
        ],
      ),
    );
  }

  // ---- hero --------------------------------------------------------------
  Widget _hero(BuildContext context, _SegContent c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: c.heroGradient.first,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed photo background.
            Image.asset(c.heroImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: c.heroGradient.first)),
            // Brand-tinted scrim: readable on the left, photo shows on the right.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    c.heroGradient.first.withValues(alpha: 0.90),
                    c.heroGradient.first.withValues(alpha: 0.50),
                    c.heroGradient.last.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 250,
                    child: Text(c.heroTitle,
                        style: GoogleFonts.poppins(
                            fontSize: 21,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black26, blurRadius: 8)
                            ])),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 230,
                    child: Text(c.heroSub,
                        style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.92))),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => _toSearch(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Explore Now',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: c.heroGradient.first)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- feature strip -----------------------------------------------------
  Widget _features(_SegContent c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final f in c.features)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(f.$1, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(height: 7),
                  Text(f.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 10, height: 1.2, color: AppColors.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- popular localities ------------------------------------------------
  Widget _localities(
      BuildContext context, _SegContent c, List<PropertyView> listings) {
    final byArea = <String, int>{};
    for (final v in listings) {
      final a = (v.raw['area'] ?? '').toString();
      if (a.isNotEmpty) byArea[a] = (byArea[a] ?? 0) + 1;
    }
    final areas = byArea.keys.toList()
      ..sort((a, b) => byArea[b]!.compareTo(byArea[a]!));
    if (areas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Popular Localities'),
        const SizedBox(height: 12),
        SizedBox(
          height: 138,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: areas.length,
            itemBuilder: (context, i) {
              final area = areas[i];
              return GestureDetector(
                onTap: () => _toSearch(context),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 82,
                        width: double.infinity,
                        child: Image.asset(
                            _localityImages[i % _localityImages.length],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: AppColors.primarySoft)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${byArea[area]} ${byArea[area] == 1 ? 'listing' : 'listings'}',
                                style: GoogleFonts.poppins(
                                    fontSize: 10, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- recommended (compact cards) ---------------------------------------
  Widget _recommended(
      BuildContext context, _SegContent c, List<PropertyView> listings) {
    final items = listings.take(6).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Recommended for You'),
        const SizedBox(height: 12),
        SizedBox(
          height: 258,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => context.push('/property/${items[i].id}'),
              child: _recCard(items[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recCard(PropertyView v) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 118,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image(
                    image: v.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.home_rounded,
                            color: AppColors.primary)),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: v.badgeColor,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(v.badge,
                        style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.favorite_border_rounded,
                        size: 15, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(v.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.inkSoft)),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _mini(Icons.bed_outlined, v.beds),
                    const SizedBox(width: 10),
                    _mini(Icons.crop_free_rounded, v.area),
                  ],
                ),
                const SizedBox(height: 7),
                Text(v.priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: v.priceColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- premium / featured ------------------------------------------------
  Widget _premium(
      BuildContext context, _SegContent c, List<PropertyView> listings) {
    final items = [...listings]
      ..sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
    final top = items.take(4).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, c.premiumTitle),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: top.length,
            itemBuilder: (context, i) => _premiumCard(context, top[i]),
          ),
        ),
      ],
    );
  }

  Widget _premiumCard(BuildContext context, PropertyView v) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image(
                    image: v.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: AppColors.primarySoft),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.prefPink,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('FEATURED',
                        style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const Positioned(
                  right: 10,
                  top: 10,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.favorite_border_rounded,
                        size: 16, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(v.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _mini(Icons.bed_outlined, v.beds),
                    const SizedBox(width: 12),
                    _mini(Icons.bathtub_outlined, v.baths),
                    const SizedBox(width: 12),
                    _mini(Icons.crop_free_rounded, v.area),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(v.priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: v.priceColor)),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/property/${v.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('Book Visit',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- bottom promo ------------------------------------------------------
  Widget _promo(BuildContext context, _SegContent c) {
    final textColor = c.promoDark ? Colors.white : AppColors.ink;
    final subColor =
        c.promoDark ? Colors.white.withValues(alpha: 0.9) : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: c.promoGradient),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.promoTitle,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
                    const SizedBox(height: 4),
                    Text(c.promoSub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 10.5, height: 1.3, color: subColor)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _toSearch(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: c.promoDark ? Colors.white : AppColors.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(c.promoCta,
                            style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: c.promoDark
                                    ? AppColors.primary
                                    : Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 120,
              height: double.infinity,
              // pg_img2 used as the promo image across all segments (per design).
              child: Image.asset('assets/images/pg_img2.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox()),
            ),
          ],
        ),
      ),
    );
  }

  // ---- shared ------------------------------------------------------------
  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: () => _toSearch(context),
            child: Text('View all',
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _mini(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkSoft),
        const SizedBox(width: 3),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.ink)),
        ),
      ],
    );
  }

}
