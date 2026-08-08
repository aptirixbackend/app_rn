import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/city_picker.dart';
import '../../../core/location/city_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../property/data/property_filter.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  static const _you = LatLng(12.9716, 77.5946); // fallback centre

  final _mapCtrl = MapController();
  LatLng _center = _you;
  PropertyFilter _filter = const PropertyFilter();

  /// Index of the pin/card currently in focus. The map pin and the bottom
  /// carousel card stay in sync through this one value.
  int _selected = 0;
  final _pageCtrl = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  LatLng _centerOf(List<PropertyView> pins) {
    if (pins.isEmpty) return _you;
    double la = 0, ln = 0;
    for (final v in pins) {
      la += v.lat!;
      ln += v.lng!;
    }
    return LatLng(la / pins.length, ln / pins.length);
  }

  /// Centre the map on the device's current GPS location.
  Future<void> _goToMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Turn on location services')));
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Location permission denied')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not get your location')));
    }
  }

  /// Zoom back out to fit all the visible property pins.
  void _recenterAll() {
    try {
      _mapCtrl.move(_center, 12.2);
    } catch (_) {}
  }

  Future<void> _openFilters() async {
    final rows = ref.read(visiblePropertiesProvider).asData?.value ?? const [];
    final localities = (<String>{
      for (final r in rows) (r['area'] ?? '').toString().trim()
    }..removeWhere((e) => e.isEmpty))
        .toList()
      ..sort();
    final f = await showFilterSheet(context, _filter, localities: localities);
    if (f != null) setState(() => _filter = f);
  }

  Future<void> _openSort() async {
    final s = await showSortSheet(context, _filter.sort);
    if (s != null) setState(() => _filter = _filter.withSort(s));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visiblePropertiesProvider);
    ref.listen(selectedCityProvider, (_, _) {
      final rows =
          ref.read(visiblePropertiesProvider).asData?.value ?? const [];
      final pins = rows
          .map(PropertyView.new)
          .where((v) => v.lat != null && v.lng != null)
          .toList();
      try {
        _mapCtrl.move(_centerOf(pins), 12.2);
      } catch (_) {}
      _selected = 0;
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
    });
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(context),
            _searchRow(context),
            const SizedBox(height: 10),
            _filterChips(context),
            const SizedBox(height: 10),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Could not load map.\n$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: AppColors.inkSoft)),
                ),
                data: (rows) {
                  final views =
                      _filter.apply(rows.map(PropertyView.new).toList());
                  final pins = views
                      .where((v) => v.lat != null && v.lng != null)
                      .toList();
                  _center = _centerOf(pins);
                  if (_selected >= pins.length) _selected = 0;
                  return Stack(
                    children: [
                      _map(pins),
                      _topOverlay(context, views.length),
                      Positioned(
                        right: 14,
                        bottom: 178,
                        child: Column(
                          children: [
                            _mapBtn(Icons.my_location_rounded,
                                _goToMyLocation),
                            const SizedBox(height: 10),
                            _mapBtn(Icons.zoom_out_map_rounded, _recenterAll),
                          ],
                        ),
                      ),
                      _carousel(context, pins),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 'map'),
    );
  }

  Widget _map(List<PropertyView> pins) {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(initialCenter: _center, initialZoom: 12.2),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.realestate.homevista',
        ),
        MarkerLayer(
          markers: [
            // Draw the selected pin last so it renders on top of the others.
            for (var i = 0; i < pins.length; i++)
              if (i != _selected) _marker(i, pins),
            if (pins.isNotEmpty && _selected < pins.length)
              _marker(_selected, pins),
          ],
        ),
      ],
    );
  }

  Marker _marker(int i, List<PropertyView> pins) {
    final v = pins[i];
    return Marker(
      point: LatLng(v.lat!, v.lng!),
      width: 110,
      height: 54,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _selectPin(i, pins),
        child: _pin(v, i == _selected),
      ),
    );
  }

  /// Tapping a pin selects it: highlight the pin, glide the carousel to its
  /// card, and recentre the map on it.
  void _selectPin(int i, List<PropertyView> pins) {
    if (i < 0 || i >= pins.length) return;
    setState(() => _selected = i);
    if (_pageCtrl.hasClients) {
      _pageCtrl.animateToPage(i,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
    _moveTo(pins[i]);
  }

  void _moveTo(PropertyView v) {
    if (v.lat == null || v.lng == null) return;
    try {
      final z = _mapCtrl.camera.zoom;
      _mapCtrl.move(LatLng(v.lat!, v.lng!), z < 13 ? 13.5 : z);
    } catch (_) {}
  }

  Widget _pin(PropertyView v, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
              horizontal: selected ? 11 : 8, vertical: selected ? 5 : 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border:
                Border.all(color: AppColors.primary, width: selected ? 0 : 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.28 : 0.18),
                  blurRadius: selected ? 8 : 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Text(v.priceShort,
              style: GoogleFonts.poppins(
                  fontSize: selected ? 12 : 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary)),
        ),
        Icon(Icons.location_on,
            color: AppColors.primary, size: selected ? 22 : 16),
      ],
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      );

  // ---- top overlay: live count + sort -----------------------------------
  Widget _topOverlay(BuildContext context, int count) {
    Widget pill({required Widget child, VoidCallback? onTap}) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: child,
          ),
        );
    return Positioned(
      top: 10,
      left: 14,
      right: 14,
      child: Row(
        children: [
          pill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 5),
                Text('$count in ${ref.watch(selectedCityProvider)}',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          pill(
            onTap: _openSort,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert_rounded,
                    size: 17, color: AppColors.ink),
                const SizedBox(width: 4),
                Text('Sort',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- bottom carousel: horizontal, two-way synced to the map -----------
  Widget _carousel(BuildContext context, List<PropertyView> pins) {
    if (pins.isEmpty) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 22,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
              ],
            ),
            child: Text('No properties match your filters',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: AppColors.inkSoft)),
          ),
        ),
      );
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: SizedBox(
        height: 150,
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: pins.length,
          // Swiping a card pans the map to its pin and highlights it.
          onPageChanged: (i) {
            setState(() => _selected = i);
            _moveTo(pins[i]);
          },
          itemBuilder: (_, i) => _mapCard(context, pins[i], i == _selected),
        ),
      ),
    );
  }

  Widget _mapCard(BuildContext context, PropertyView v, bool selected) {
    String? distance;
    if (v.lat != null && v.lng != null) {
      final km = const Distance()
          .as(LengthUnit.Kilometer, _center, LatLng(v.lat!, v.lng!));
      distance = '${km.toStringAsFixed(1)} km away';
    }
    return GestureDetector(
      onTap: () => context.push('/property/${v.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                      image: v.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.primarySoft)),
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
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(v.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.inkSoft),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                              distance == null
                                  ? v.location
                                  : '${v.location} · $distance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5, color: AppColors.inkSoft)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        _spec(Icons.bed_outlined, v.beds),
                        _spec(Icons.bathtub_outlined, v.baths),
                        _spec(Icons.crop_free_rounded, v.area),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(v.priceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: v.priceColor)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.primary),
                      ],
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

  Widget _spec(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.inkSoft),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.ink)),
        ],
      );

  // ---- header ------------------------------------------------------------
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore Properties',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Find your perfect space',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  Widget _searchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Search by locality, city or project',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, color: AppColors.inkSoft)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openFilters,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _filter.hasFilters ? AppColors.primarySoft : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _filter.hasFilters
                        ? AppColors.primary
                        : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 18,
                      color: _filter.hasFilters
                          ? AppColors.primary
                          : AppColors.ink),
                  const SizedBox(width: 6),
                  Text('Filter',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _filter.hasFilters
                              ? AppColors.primary
                              : AppColors.ink)),
                  if (_filter.hasFilters) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(BuildContext context) {
    Widget chip(IconData icon, String label,
            {bool active = false, VoidCallback? onTap}) =>
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: onTap ?? _openFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primarySoft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: active ? AppColors.primary : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 15,
                      color: active ? AppColors.primary : AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.ink)),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: active ? AppColors.primary : AppColors.inkSoft),
                ],
              ),
            ),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip(Icons.location_on_outlined, ref.watch(selectedCityProvider),
              active: true, onTap: () => showCitySheet(context, ref)),
          chip(Icons.swap_horiz_rounded, _filter.segmentLabel,
              active: _filter.segment != Segment.all),
          chip(Icons.currency_rupee_rounded, _filter.priceLabel,
              active: _filter.priceIdx != 0),
          chip(Icons.apartment_rounded, _filter.type ?? 'Property Type',
              active: _filter.type != null),
        ],
      ),
    );
  }
}
