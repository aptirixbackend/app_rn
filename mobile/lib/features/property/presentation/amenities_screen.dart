import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import 'widgets/posting_widgets.dart';

const _amenities = <(String, IconData)>[
  ('Lift', Icons.elevator),
  ('Parking', Icons.directions_car_filled_outlined),
  ('Power Backup', Icons.bolt),
  ('24x7 Security', Icons.shield_outlined),
  ('CCTV', Icons.videocam_outlined),
  ('Gym', Icons.fitness_center),
  ('Swimming Pool', Icons.pool),
  ('Club House', Icons.house_outlined),
  ('Children Play Area', Icons.child_care),
  ('Garden', Icons.local_florist_outlined),
  ('Visitor Parking', Icons.local_parking),
  ('Fire Safety', Icons.local_fire_department_outlined),
];

class AmenitiesScreen extends ConsumerStatefulWidget {
  const AmenitiesScreen({super.key, this.propertyId});
  final String? propertyId;

  @override
  ConsumerState<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends ConsumerState<AmenitiesScreen> {
  final _selected = <String>{'Lift', 'Parking', '24x7 Security'};
  final _features = <String>[];
  final _featureCtrl = TextEditingController();
  final _highlightCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _featureCtrl.dispose();
    _highlightCtrl.dispose();
    super.dispose();
  }

  void _addFeature(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    setState(() {
      _features.add(t);
      _featureCtrl.clear();
    });
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      if (widget.propertyId != null) {
        await ref.read(propertyRepositoryProvider).saveAmenities(
              widget.propertyId!,
              amenities: _selected.toList(),
              additionalFeatures: _features,
              highlights: _highlightCtrl.text.trim().isEmpty
                  ? null
                  : _highlightCtrl.text.trim(),
            );
      }
    } catch (_) {
      // Preview mode — ignore and continue.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) {
      context.go('/post-property/media', extra: widget.propertyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            PostingProgressBar(
              step: 4,
              onBack: () => context.go('/post-property/pricing',
                  extra: {'id': widget.propertyId}),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    _amenitiesCard(),
                    const SizedBox(height: 20),
                    Text('Additional Features (Optional)',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _featureCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _addFeature,
                      decoration: const InputDecoration(
                        prefixIcon:
                            Icon(Icons.add, color: AppColors.primary, size: 22),
                        hintText: 'E.g. Pet Friendly, Gas Pipeline, Intercom, etc.',
                      ),
                    ),
                    if (_features.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _features
                            .map((f) => _featureChip(f))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Anything unique about your property?',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _highlightCtrl,
                      maxLines: 4,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        hintText:
                            'Add unique highlights to attract more buyers or tenants...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add amenities &\nfeatures',
                  style: GoogleFonts.poppins(
                      fontSize: 23, height: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Let buyers know what makes your\nproperty special',
                  style: GoogleFonts.poppins(
                      fontSize: 13, height: 1.35, color: AppColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Image.asset('assets/images/features.png', width: 104, fit: BoxFit.contain),
      ],
    );
  }

  Widget _amenitiesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Popular Amenities',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Select all that apply',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            childAspectRatio: 0.80,
            children:
                _amenities.map((a) => _amenityChip(a.$1, a.$2)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _amenityChip(String label, IconData icon) {
    final selected = _selected.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(label);
        } else {
          _selected.add(label);
        }
      }),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 22,
                    color: selected ? AppColors.primary : AppColors.inkSoft),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        height: 1.1,
                        fontWeight: FontWeight.w500,
                        color: selected ? AppColors.primary : AppColors.ink)),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _featureChip(String f) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, color: AppColors.primary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _features.remove(f)),
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _loading ? null : _continue,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Continue'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          const SecureNote(),
        ],
      ),
    );
  }
}
