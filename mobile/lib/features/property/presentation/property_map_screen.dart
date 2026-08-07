import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import '../data/property_view.dart';

/// Full-screen map focused on ONE property — the exact location for the
/// listing the user is viewing, with a "Get Directions" hand-off to the
/// device's maps app.
class PropertyMapScreen extends ConsumerWidget {
  const PropertyMapScreen({super.key, required this.propertyId});
  final String propertyId;

  Future<void> _directions(
      BuildContext context, double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(propertyByIdProvider(propertyId));
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _msg('Could not load location.\n$e'),
        data: (row) {
          if (row == null) return _msg('Property not found.');
          final v = PropertyView(row);
          if (v.lat == null || v.lng == null) {
            return _msg('Location not available for this property.');
          }
          final point = LatLng(v.lat!, v.lng!);
          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 15.5),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.realestate.homevista',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 150,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: _pin(v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _circleBtn(Icons.arrow_back_rounded,
                        () => context.canPop() ? context.pop() : context.go('/home')),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: _bottomCard(context, v, point),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pin(PropertyView v) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Text(v.priceShort,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const Icon(Icons.location_on, color: AppColors.primary, size: 34),
        ],
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: AppColors.ink, size: 22),
        ),
      );

  Widget _bottomCard(BuildContext context, PropertyView v, LatLng point) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(v.location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, color: AppColors.inkSoft)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/property/${v.id}'),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () =>
                      _directions(context, point.latitude, point.longitude),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Get Directions'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _msg(String text) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(text,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 13, color: AppColors.inkSoft)),
          ),
        ),
      );
}
