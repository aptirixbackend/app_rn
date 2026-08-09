import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/location/city_picker.dart';
import '../../../core/location/city_store.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../property/data/property_filter.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';
import '../../property/data/seen_store.dart';

class _Trust {
  const _Trust(this.icon, this.color, this.bg, this.title, this.subtitle);
  final IconData icon;
  final Color color, bg;
  final String title, subtitle;
}

const _cats = <(String, IconData, Color, Color)>[
  ('All', Icons.home_rounded, AppColors.primary, AppColors.primarySoft),
  ('Rent', Icons.house_outlined, AppColors.prefGreen, AppColors.prefGreenBg),
  ('Buy', Icons.king_bed_outlined, AppColors.prefOrange, AppColors.prefOrangeBg),
  ('PG / Co-living', Icons.groups_outlined, AppColors.prefPurple, AppColors.prefPurpleBg),
  ('Commercial', Icons.business_outlined, AppColors.prefBlue, AppColors.prefBlueBg),
  ('Plots / Land', Icons.location_on_outlined, AppColors.prefGreen, AppColors.prefGreenBg),
  ('Stay', Icons.night_shelter_outlined, AppColors.prefPink, AppColors.prefPinkBg),
];

// (label, count, image, filter-key handled by _exploreFilter)
const _exploreCats = <(String, String, String, String)>[
  ('Apartments', '12,345+', 'assets/images/tellus_properity.png', 'Apartment'),
  ('Villas', '2,345+', 'assets/images/for_home.png', 'Villa'),
  ('Stays', '980+', 'assets/images/rent_img1.png', 'Stay'),
  ('PG / Co-living', '1,234+', 'assets/images/features.png', 'PG'),
  ('Coworking', '640+', 'assets/images/search_home.png', 'Coworking'),
  ('Commercial', '1,118+', 'assets/images/review_page.png', 'Commercial'),
  ('Plots / Land', '842+', 'assets/images/location.png', 'Plot'),
];

/// Map an "Explore by Category" tile to the filter it opens.
PropertyFilter _exploreFilter(String key) {
  switch (key) {
    case 'PG':
      return const PropertyFilter(segment: Segment.pg);
    case 'Commercial':
      return const PropertyFilter(segment: Segment.commercial);
    case 'Stay':
      return const PropertyFilter(segment: Segment.stay);
    default:
      return PropertyFilter.ofType(key);
  }
}

const _trust = <_Trust>[
  _Trust(Icons.verified_user_outlined, AppColors.prefGreen, AppColors.prefGreenBg,
      'Verified Listings', '100% verified\nproperties'),
  _Trust(Icons.sell_outlined, AppColors.prefPink, AppColors.prefPinkBg,
      'Best Prices', 'Get the best\nmarket prices'),
  _Trust(Icons.headset_mic_outlined, AppColors.prefPurple, AppColors.prefPurpleBg,
      'Expert Support', "We're here to\nhelp you"),
  _Trust(Icons.lock_outline, AppColors.prefBlue, AppColors.prefBlueBg,
      'Safe & Secure', 'Your data is always\nprotected'),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _cat = 0;

  @override
  void initState() {
    super.initState();
    // The user is authenticated by the time they reach Home — register this
    // device for push (idempotent).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushServiceProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _searchBar(),
                    const SizedBox(height: 16),
                    _categoryChips(),
                    const SizedBox(height: 14),
                    _cityLocalityChips(),
                    _heroBanner(),
                    const SizedBox(height: 22),
                    _collections(),
                    const SizedBox(height: 22),
                    _recommended(),
                    const SizedBox(height: 22),
                    _exploreByCategory(),
                    const SizedBox(height: 22),
                    _trendingLocalities(),
                    const SizedBox(height: 22),
                    _trustRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 'home'),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          IconButton(
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.menu_rounded, color: AppColors.ink)),
          const Icon(Icons.home_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700),
                  children: const [
                    TextSpan(text: 'Rento', style: TextStyle(color: AppColors.ink)),
                    TextSpan(
                        text: 'Rent', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showCitySheet(context, ref),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(ref.watch(selectedCityProvider),
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 15, color: AppColors.inkSoft),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const NotificationBell(),
          const SizedBox(width: 4),
          Builder(builder: (context) {
            final avatar = ref.watch(userAvatarProvider).asData?.value;
            final hasAvatar = avatar != null && avatar.isNotEmpty;
            return GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                child: hasAvatar
                    ? null
                    : const Icon(Icons.person,
                        color: AppColors.primary, size: 20),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.go('/search'),
        child: Container(
          height: 52,
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
                child: Text('Search by locality, city or project',
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, color: AppColors.inkSoft)),
              ),
              const Icon(Icons.tune_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cats.length,
        itemBuilder: (context, i) {
          final c = _cats[i];
          final selected = _cat == i;
          return GestureDetector(
            onTap: () {
              const segPaths = [null, 'rent', 'buy', 'pg', 'commercial',
                  'plots', 'stay'];
              final seg = segPaths[i];
              if (seg == null) {
                setState(() => _cat = 0);
              } else {
                context.push('/browse/$seg');
              }
            },
            child: Container(
              width: 74,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 1.4 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: c.$4, borderRadius: BorderRadius.circular(10)),
                    child: Icon(c.$2, color: c.$3, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(c.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: selected ? AppColors.primary : AppColors.ink)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- City-based locality quick filters --------------------------------
  Widget _cityLocalityChips() {
    final city = ref.watch(selectedCityProvider);
    final rows =
        ref.watch(visiblePropertiesProvider).asData?.value ?? const [];
    final byArea = <String, int>{};
    for (final r in rows) {
      final a = (r['area'] ?? '').toString();
      if (a.isNotEmpty) byArea[a] = (byArea[a] ?? 0) + 1;
    }
    final areas = byArea.keys.toList()
      ..sort((a, b) => byArea[b]!.compareTo(byArea[a]!));
    if (areas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Popular in $city',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final a in areas.take(8))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => context.push('/search',
                        extra: PropertyFilter(areas: {a})),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(a,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _heroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 208,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFEDE9FF), Color(0xFFF5F2FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 6, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Find. Choose. Own.',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.poppins(
                            fontSize: 17.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                        children: const [
                          TextSpan(text: "Discover a place you'll "),
                          TextSpan(
                              text: 'love to live in',
                              style: TextStyle(color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Verified listings, best prices\nand trusted by thousands.',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            height: 1.35,
                            color: AppColors.inkSoft)),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => context.go('/search'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Explore Now', style: TextStyle(fontSize: 12.5)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/home_signup.png',
                        fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFF1EDFF), Color(0x00F1EDFF)],
                          stops: [0.0, 0.55],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                children: [
                  Text('View all',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<PropertyView> _filterByCat(List<PropertyView> list) {
    switch (_cat) {
      case 1:
        return list.where((v) => v.purpose == 'rent').toList();
      case 2:
        return list.where((v) => v.purpose == 'sell').toList();
      case 3:
        return list.where((v) {
          final t = v.propertyType.toLowerCase();
          return t.contains('coliving') || t.contains('pg');
        }).toList();
      case 4:
        return list.where((v) {
          final t = v.propertyType.toLowerCase();
          return t == 'commercial' || t.contains('coworking');
        }).toList();
      case 5:
        return list
            .where((v) => v.propertyType.toLowerCase().contains('plot'))
            .toList();
      case 6:
        return list.where((v) => v.purpose == 'stay').toList();
      default:
        return list;
    }
  }

  Widget _recommended() {
    final async = ref.watch(visiblePropertiesProvider);
    final seen = ref.watch(seenIdsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recommended for You',
            onViewAll: () => context.go('/search')),
        const SizedBox(height: 12),
        SizedBox(
          height: 262,
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            error: (e, _) => Center(
              child: Text('Could not load listings',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, color: AppColors.inkSoft)),
            ),
            data: (rows) {
              final views = seenLast(
                  _filterByCat(rows.map(PropertyView.new).toList()), seen);
              if (views.isEmpty) {
                return Center(
                  child: Text('No listings in this category',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: AppColors.inkSoft)),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: views.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => context.push('/property/${views[i].id}'),
                  child: _listingCard(views[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _listingCard(PropertyView v) {
    return Container(
      width: 250,
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
            height: 128,
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
                  left: 10,
                  top: 10,
                  child: _pill(v.badge, v.badgeColor, Colors.white),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_border_rounded,
                        size: 17, color: AppColors.ink),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.inkSoft),
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
                Text(v.priceLabel,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: v.priceColor)),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _spec(Icons.bed_outlined, v.beds),
                    _spec(Icons.bathtub_outlined, v.baths),
                    _spec(Icons.crop_free_rounded, v.area),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 9, color: fg, fontWeight: FontWeight.w600)),
      );

  Widget _spec(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.inkSoft),
        const SizedBox(width: 3),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.ink)),
      ],
    );
  }

  int _typeCount(List<Map<String, dynamic>> rows, String key) {
    return rows.where((r) {
      final t = (r['property_type'] ?? '').toString().toLowerCase();
      if (key == 'PG') return t == 'pg' || t == 'coliving';
      return t == key.toLowerCase();
    }).length;
  }

  Widget _exploreByCategory() {
    final rows = ref.watch(visiblePropertiesProvider).asData?.value ??
        const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Explore by Category'),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _exploreCats.length,
            itemBuilder: (context, i) {
              final c = _exploreCats[i];
              final count = _typeCount(rows, c.$4);
              return GestureDetector(
                onTap: () => context.push('/search',
                    extra: _exploreFilter(c.$4)),
                child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.$1,
                            style: GoogleFonts.poppins(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('$count ${count == 1 ? 'listing' : 'listings'}',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, color: AppColors.inkSoft)),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Image.asset(c.$3,
                          width: 68, height: 52, fit: BoxFit.contain),
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

  // ---- Collections (curated filter shortcuts) ---------------------------
  Widget _collections() {
    final items = <(String, String, IconData, Color, Color, PropertyFilter)>[
      ('Budget Homes', 'Under ₹40L', Icons.savings_outlined,
          AppColors.prefGreen, AppColors.prefGreenBg,
          const PropertyFilter(segment: Segment.buy, priceIdx: 1)),
      ('Premium Villas', 'Luxury living', Icons.villa_outlined,
          AppColors.prefOrange, AppColors.prefOrangeBg,
          PropertyFilter.ofType('Villa')),
      ('PG & Co-living', 'Students & pros', Icons.groups_outlined,
          AppColors.prefPurple, AppColors.prefPurpleBg,
          const PropertyFilter(segment: Segment.pg)),
      ('Stays < ₹2K', 'By the night', Icons.night_shelter_outlined,
          AppColors.prefPink, AppColors.prefPinkBg,
          const PropertyFilter(segment: Segment.stay, priceIdx: 2)),
      ('Office Spaces', 'Commercial', Icons.business_outlined,
          AppColors.prefBlue, AppColors.prefBlueBg,
          const PropertyFilter(segment: Segment.commercial)),
      ('Plots & Land', 'Build your own', Icons.terrain_outlined,
          AppColors.prefGreen, AppColors.prefGreenBg,
          const PropertyFilter(segment: Segment.plots)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Collections'),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return GestureDetector(
                onTap: () => context.push('/search', extra: it.$6),
                child: Container(
                  width: 156,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: it.$5,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Icon(it.$3, color: it.$4, size: 20),
                      ),
                      const Spacer(),
                      Text(it.$1,
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(it.$2,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.inkSoft)),
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

  // ---- Trending localities (from live data) -----------------------------
  Widget _trendingLocalities() {
    const imgs = [
      'assets/images/tellus_properity.png',
      'assets/images/search_home.png',
      'assets/images/for_home.png',
      'assets/images/flat.png',
      'assets/images/location.png',
      'assets/images/review_page.png',
    ];
    final rows = ref.watch(visiblePropertiesProvider).asData?.value;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final byArea = <String, int>{};
    for (final r in rows) {
      final a = (r['area'] ?? '').toString();
      if (a.isNotEmpty) byArea[a] = (byArea[a] ?? 0) + 1;
    }
    final areas = byArea.keys.toList()
      ..sort((a, b) => byArea[b]!.compareTo(byArea[a]!));
    final top = areas.take(6).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Top Localities',
            onViewAll: () => context.go('/search')),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: top.length,
            itemBuilder: (context, i) {
              final area = top[i];
              return GestureDetector(
                onTap: () => context.push('/search',
                    extra: PropertyFilter(areas: {area})),
                child: Container(
                  width: 132,
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
                        height: 76,
                        width: double.infinity,
                        child: Image.asset(imgs[i % imgs.length],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: AppColors.primarySoft)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            Text('${byArea[area]} listings',
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

  Widget _trustRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: _trust
              .map((t) => Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration:
                              BoxDecoration(color: t.bg, shape: BoxShape.circle),
                          child: Icon(t.icon, color: t.color, size: 19),
                        ),
                        const SizedBox(height: 6),
                        Text(t.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 10.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                height: 1.25,
                                color: AppColors.inkSoft)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
