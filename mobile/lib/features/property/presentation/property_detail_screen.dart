import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../engagement/data/engagement_repository.dart';
import '../data/property_repository.dart';
import '../data/property_view.dart';
import '../data/seen_store.dart';
import 'stay_booking_sheet.dart';
import 'video_player_screen.dart';

IconData _amenityIcon(String a) {
  final k = a.toLowerCase();
  if (k.contains('lift')) return Icons.elevator;
  if (k.contains('power')) return Icons.bolt;
  if (k.contains('security')) return Icons.shield_outlined;
  if (k.contains('parking')) return Icons.local_parking;
  if (k.contains('gym')) return Icons.fitness_center;
  if (k.contains('pool')) return Icons.pool;
  if (k.contains('club')) return Icons.house_outlined;
  if (k.contains('play') || k.contains('child')) return Icons.child_care;
  if (k.contains('cctv')) return Icons.videocam_outlined;
  if (k.contains('garden')) return Icons.local_florist_outlined;
  if (k.contains('wifi') || k.contains('wi-fi')) return Icons.wifi;
  if (k.contains('meal')) return Icons.restaurant_outlined;
  if (k.contains('housekeep')) return Icons.cleaning_services_outlined;
  if (k.contains('laundry')) return Icons.local_laundry_service_outlined;
  return Icons.check_circle_outline;
}

String _fmtDate(Object? iso) {
  final s = iso?.toString() ?? '';
  final d = DateTime.tryParse(s);
  if (d == null) return s.isEmpty ? '—' : s;
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class PropertyDetailScreen extends ConsumerStatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  bool _descExpanded = false;
  int _photo = 0;
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    // Record this listing as seen so it drops to the end of "Recommended".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(seenIdsProvider.notifier).markSeen(widget.propertyId);
    });
  }

  /// Log a "view" activity event once the property loads (fire-and-forget).
  void _trackView(Map<String, dynamic> row) {
    if (_tracked) return;
    _tracked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(engagementRepositoryProvider).track('view',
          propertyId: widget.propertyId,
          ownerId: row['owner_id']?.toString(),
          meta: {'property_type': row['property_type'], 'city': row['city']});
    });
  }

  void _soon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggleFav(String id) async {
    final saved =
        await ref.read(engagementRepositoryProvider).toggleFavorite(id);
    ref.invalidate(favoriteIdsProvider);
    ref.invalidate(savedPropertiesProvider);
    _snack(saved ? 'Saved to favorites' : 'Removed from favorites');
  }

  Future<void> _enquire(String propertyId, String? ownerId, String kind) async {
    final created = await ref
        .read(engagementRepositoryProvider)
        .createLead(propertyId, ownerId, kind: kind);
    ref
      ..invalidate(myEnquiriesProvider)
      ..invalidate(ownerLeadsProvider)
      ..invalidate(notificationCountProvider);
    _snack(created
        ? 'Enquiry sent to the owner'
        : "You've already enquired on this property");
  }

  /// Open the phone dialer with the owner's number and log the contact.
  Future<void> _callOwner(PropertyView v, String? ownerId) async {
    _enquire(v.id, ownerId, 'contact');
    final uri = Uri(
        scheme: 'tel',
        path: v.contactPhone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (!await launchUrl(uri)) _snack('Could not open the dialer');
  }

  /// Open WhatsApp to the owner's number and log the enquiry.
  Future<void> _whatsappOwner(PropertyView v, String? ownerId) async {
    _enquire(v.id, ownerId, 'whatsapp');
    final digits = v.contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open WhatsApp');
    }
  }

  Future<void> _scheduleVisit(String propertyId, String? ownerId) async {
    final visited =
        ref.read(myVisitedIdsProvider).asData?.value ?? const <String>{};
    if (visited.contains(propertyId)) {
      _snack("You've already requested a visit for this property");
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null) return;
    final created = await ref
        .read(engagementRepositoryProvider)
        .createVisit(propertyId, ownerId, date: date);
    ref
      ..invalidate(myVisitsProvider)
      ..invalidate(ownerVisitsProvider)
      ..invalidate(notificationCountProvider);
    _snack(created
        ? 'Site visit requested for ${date.day}/${date.month}/${date.year}'
        : "You've already requested a visit for this property");
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyByIdProvider(widget.propertyId));
    final favs =
        ref.watch(favoriteIdsProvider).asData?.value ?? const <String>{};
    final topRow = async.asData?.value;
    final topView = topRow != null ? PropertyView(topRow) : null;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _center('Could not load this property.\n$e'),
          data: (row) {
            if (row == null) return _center('Property not found.');
            _trackView(row);
            final v = PropertyView(row);
            return Column(
              children: [
                _topBar(v, favs.contains(v.id)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _gallery(v),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _titleBlock(v, row),
                              const SizedBox(height: 14),
                              _highlightsBar(v, row),
                              _priceInsights(v),
                              const SizedBox(height: 20),
                              _description(v),
                              const SizedBox(height: 20),
                              _amenities(v),
                              const SizedBox(height: 20),
                              _attributesSection(v),
                              _location(v),
                              const SizedBox(height: 20),
                              _propertyDetails(v, row),
                              const SizedBox(height: 20),
                              _photosVideos(v),
                              const SizedBox(height: 20),
                              _landmarks(),
                              const SizedBox(height: 20),
                              _ownerCard(v, row),
                              const SizedBox(height: 20),
                              _similar(v),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: topView == null
          ? null
          : _bottomBar(topView, topRow!, favs.contains(topView.id)),
    );
  }

  Widget _center(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.inkSoft)),
        ),
      );

  // ---- top bar -----------------------------------------------------------
  Widget _topBar(PropertyView v, bool isFav) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              icon: const Icon(Icons.arrow_back_rounded)),
          const Icon(Icons.home_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(
                style:
                    GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                children: const [
                  TextSpan(text: 'Home', style: TextStyle(color: AppColors.ink)),
                  TextSpan(
                      text: 'Vista', style: TextStyle(color: AppColors.primary)),
                ],
              )),
              Text('Find your perfect space',
                  style:
                      GoogleFonts.poppins(fontSize: 9, color: AppColors.inkSoft)),
            ],
          ),
          const Spacer(),
          IconButton(
              onPressed: () => _toggleFav(v.id),
              icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? Colors.red : AppColors.ink)),
          IconButton(
              onPressed: _soon,
              icon: const Icon(Icons.ios_share_rounded,
                  color: AppColors.ink, size: 20)),
        ],
      ),
    );
  }

  void _openVideo(PropertyView v) {
    if (v.videoUrl == null) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(url: v.videoUrl!, title: v.title)));
  }

  // ---- gallery -----------------------------------------------------------
  Widget _gallery(PropertyView v) {
    final images = v.galleryImages;
    final count = images.length;
    final sel = _photo.clamp(0, count - 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/property/${v.id}/gallery'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image(
                        image: images[sel],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                            color: AppColors.primarySoft,
                            child: const Icon(Icons.home_rounded,
                                color: AppColors.primary, size: 40)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: v.badgeColor,
                        borderRadius: BorderRadius.circular(7)),
                    child: Text(v.badge,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(7)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('${sel + 1} / $count',
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                if (v.hasVideo)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: () => _openVideo(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Play Video Tour',
                                style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => setState(() => _photo = i),
                child: Container(
                  width: 76,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel == i
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                        image: images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: AppColors.primarySoft)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- title -------------------------------------------------------------
  Widget _titleBlock(PropertyView v, Map<String, dynamic> row) {
    final floor = row['floor_number'];
    final total = row['total_floors'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(v.title,
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w700)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(v.priceLabel.split(' /').first,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                if (v.purpose != 'sell')
                  Text('/ ${row['price_period'] ?? 'month'}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(v.location,
            style:
                GoogleFonts.poppins(fontSize: 13.5, color: AppColors.inkSoft)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _typeSpecChips(v, floor, total),
        ),
      ],
    );
  }

  /// Type-appropriate quick chips under the title.
  List<Widget> _typeSpecChips(PropertyView v, dynamic floor, dynamic total) {
    final t = v.propertyType.toLowerCase();
    final a = v.attributes;
    if (t.contains('plot')) {
      final dim = (a['plot_length'] != null && a['plot_width'] != null)
          ? '${a['plot_length']}×${a['plot_width']} ft'
          : '';
      return [
        _specChip(Icons.crop_free_rounded, v.area),
        if (dim.isNotEmpty) _specChip(Icons.straighten_rounded, dim),
        if (v.attr('approval').isNotEmpty)
          _specChip(Icons.verified_outlined, v.attr('approval')),
      ];
    }
    if (t.contains('pg') || t.contains('coliving')) {
      return [
        _specChip(Icons.single_bed_outlined,
            v.sharing.isNotEmpty ? v.sharing : v.beds),
        _specChip(Icons.crop_free_rounded, v.area),
        if (v.furnishing.isNotEmpty)
          _specChip(Icons.chair_outlined, v.furnishing),
      ];
    }
    if (t.contains('commercial') || t.contains('coworking')) {
      return [
        _specChip(Icons.crop_free_rounded, v.area),
        if (v.attr('seats').isNotEmpty)
          _specChip(Icons.event_seat_outlined, '${v.attr('seats')} seats'),
        if (v.attr('washrooms').isNotEmpty)
          _specChip(Icons.wc_outlined, '${v.attr('washrooms')} washrooms'),
        if (floor != null && total != null)
          _specChip(Icons.stairs_outlined, 'Floor $floor/$total'),
      ];
    }
    if (v.purpose == 'stay') {
      return [
        if (v.maxGuests.isNotEmpty)
          _specChip(Icons.people_alt_outlined, '${v.maxGuests} guests'),
        _specChip(Icons.bed_outlined, v.beds),
        _specChip(Icons.crop_free_rounded, v.area),
      ];
    }
    return [
      _specChip(Icons.bed_outlined, v.beds),
      _specChip(Icons.bathtub_outlined, v.baths),
      _specChip(Icons.crop_free_rounded, v.area),
      if (floor != null && total != null)
        _specChip(Icons.stairs_outlined, '${floor}th Floor / $total'),
    ];
  }

  Widget _specChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.inkSoft),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _highlightsBar(PropertyView v, Map<String, dynamic> row) {
    Widget item(IconData icon, String title, String sub) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: AppColors.prefGreen, size: 20),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              if (sub.isNotEmpty)
                Text(sub,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 9.5, color: AppColors.inkSoft)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.prefGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          item(Icons.verified_user_rounded, 'Verified Listing', ''),
          item(Icons.star_border_rounded, 'Owner Posted', ''),
          item(Icons.event_available_outlined, 'Available from',
              _fmtDate(row['available_from'])),
        ],
      ),
    );
  }

  Widget _sectionHead(String title, {String? action, VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700)),
        if (action != null)
          GestureDetector(
            onTap: onTap ?? _soon,
            child: Text(action,
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
      ],
    );
  }

  Widget _description(PropertyView v) {
    final text = (v.raw['highlights'] ?? '').toString();
    final desc = text.isEmpty
        ? 'No description provided for this property.'
        : text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Description'),
        const SizedBox(height: 8),
        Text(desc,
            maxLines: _descExpanded ? null : 3,
            overflow: _descExpanded ? null : TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 13, height: 1.5, color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _descExpanded = !_descExpanded),
          child: Row(
            children: [
              Text(_descExpanded ? 'Read less' : 'Read more',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              Icon(
                  _descExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  IconData _attrIcon(String label) {
    switch (label) {
      case 'Occupancy':
        return Icons.groups_outlined;
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Preferred For':
        return Icons.people_alt_outlined;
      case 'Gate Timing':
        return Icons.access_time_rounded;
      case 'Notice Period':
        return Icons.event_note_outlined;
      case 'Dimensions':
        return Icons.straighten_rounded;
      case 'Boundary Wall':
        return Icons.fence_outlined;
      case 'Approval':
        return Icons.verified_outlined;
      case 'Seats / Desks':
        return Icons.event_seat_outlined;
      case 'Washrooms':
        return Icons.wc_outlined;
      case 'Lock-in':
        return Icons.lock_clock_outlined;
      case 'Parking':
        return Icons.local_parking;
      case 'Balconies':
        return Icons.balcony_outlined;
      case 'Stay Type':
        return Icons.hotel_outlined;
      case 'Max Guests':
        return Icons.people_alt_outlined;
      case 'Min Nights':
        return Icons.nights_stay_outlined;
      case 'Check-in':
        return Icons.login_rounded;
      case 'Check-out':
        return Icons.logout_rounded;
      case 'Monthly Rate':
        return Icons.currency_rupee_rounded;
      default:
        return Icons.info_outline;
    }
  }

  static String _money(num v) {
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Rough EMI on 80% of the price at 8.5% for 20 years.
  int _emi(num price) {
    final p = price.toDouble() * 0.8;
    const r = 0.085 / 12;
    const n = 240;
    final f = math.pow(1 + r, n);
    return (p * r * f / (f - 1)).round();
  }

  /// 99acres-style price insights: price/sq.ft + EMI (buy), deposit/maintenance
  /// (rent/pg), monthly + min-nights (stay).
  Widget _priceInsights(PropertyView v) {
    final a = v.attributes;
    final chips = <(IconData, String, String)>[];
    if (v.purpose == 'sell') {
      final carpet = v.carpetArea;
      final price = v.price;
      if (carpet != null && carpet > 0 && price != null) {
        chips.add((Icons.straighten_rounded, 'Price / sq.ft',
            '₹${_money((price / carpet).round())}'));
      }
      if (price != null) {
        chips.add((Icons.account_balance_outlined, 'Est. EMI',
            '₹${_money(_emi(price))}/mo'));
      }
    } else if (v.purpose == 'stay') {
      final m = num.tryParse(v.priceMonth);
      if (m != null) {
        chips.add((Icons.calendar_month_outlined, 'Monthly', '₹${_money(m)}'));
      }
      final mn = (a['min_nights'] ?? '').toString();
      if (mn.isNotEmpty) {
        chips.add((Icons.nights_stay_outlined, 'Min Nights', mn));
      }
    } else {
      final dep = num.tryParse((a['deposit'] ?? '').toString());
      if (dep != null && dep > 0) {
        chips.add((Icons.savings_outlined, 'Deposit', '₹${_money(dep)}'));
      }
      final maint = num.tryParse((a['maintenance'] ?? '').toString());
      if (maint != null && maint > 0) {
        chips.add(
            (Icons.build_outlined, 'Maintenance', '₹${_money(maint)}/mo'));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0)
                Container(width: 1, height: 34, color: AppColors.border),
              Expanded(
                child: Column(
                  children: [
                    Icon(chips[i].$1, size: 18, color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(chips[i].$3,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(chips[i].$2,
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Type-specific details (PG sharing/food/gender/timing, plot dimensions, …).
  Widget _attributesSection(PropertyView v) {
    final rows = v.attributeRows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final t = v.propertyType.toLowerCase();
    final title = t.contains('stay')
        ? 'Stay Details'
        : (t.contains('pg') || t.contains('coliving'))
            ? 'PG / Co-living Details'
            : t.contains('plot')
                ? 'Plot Details'
                : (t.contains('commercial') || t.contains('coworking'))
                    ? 'Space Details'
                    : 'More Details';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead(title),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Icon(_attrIcon(rows[i].$1),
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(rows[i].$1,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: AppColors.inkSoft)),
                      const Spacer(),
                      Text(rows[i].$2,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _amenities(PropertyView v) {
    final items = v.amenities.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Amenities', action: 'View all'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.92,
          children: items
              .map((a) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_amenityIcon(a),
                            size: 20, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(a,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 9, height: 1.1)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _location(PropertyView v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Location',
            action: 'View on Map',
            onTap: () => context.push('/property/${v.id}/map')),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: (v.lat != null && v.lng != null)
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(v.lat!, v.lng!),
                                initialZoom: 14.5,
                                interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.none),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.realestate.homevista',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(v.lat!, v.lng!),
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.topCenter,
                                      child: const Icon(Icons.location_on,
                                          color: AppColors.primary, size: 38),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: GestureDetector(
                              onTap: () =>
                                  context.push('/property/${v.id}/map'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.open_in_full_rounded,
                                        size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text('Open Map',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Image.asset('assets/images/location.png',
                        fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(v.location,
                          style: GoogleFonts.poppins(
                              fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _near(Icons.directions_transit, 'Metro', '2.4 km'),
                    _near(Icons.school_outlined, 'School', '1.2 km'),
                    _near(Icons.local_hospital_outlined, 'Hospital', '1.8 km'),
                    _near(Icons.storefront_outlined, 'Mall', '2.1 km'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _near(IconData icon, String label, String dist) => Column(
        children: [
          Icon(icon, size: 18, color: AppColors.inkSoft),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10.5, fontWeight: FontWeight.w500)),
          Text(dist,
              style:
                  GoogleFonts.poppins(fontSize: 9.5, color: AppColors.inkSoft)),
        ],
      );

  /// General detail rows, adapted to the property type (plots omit
  /// furnishing/age/floor, etc.).
  List<(IconData, String, String)> _detailPairs(
      PropertyView v, Map<String, dynamic> row) {
    final t = v.propertyType.toLowerCase();
    final isPlot = t.contains('plot');
    final isStay = v.purpose == 'stay';
    final pairs = <(IconData, String, String)>[];
    pairs.add((Icons.apartment_rounded, 'Property Type', v.propertyType));
    pairs.add((
      Icons.sell_outlined,
      'Listing Type',
      v.purpose == 'sell' ? 'For Sale' : (isStay ? 'For Stay' : 'For Rent'),
    ));
    if (!isPlot && v.furnishing.isNotEmpty) {
      pairs.add((Icons.weekend_outlined, 'Furnishing', v.furnishing));
    }
    final facing = '${row['facing'] ?? ''}';
    if (facing.isNotEmpty) pairs.add((Icons.explore_outlined, 'Facing', facing));
    final age = '${row['property_age'] ?? ''}';
    if (!isPlot && !isStay && age.isNotEmpty) {
      pairs.add((Icons.event_outlined, 'Age', age));
    }
    final floor = row['floor_number'];
    final total = row['total_floors'];
    if (!isPlot && floor != null) {
      pairs.add((Icons.stairs_outlined, 'Floor',
          total != null ? '$floor of $total' : '$floor'));
    }
    if (v.carpetArea != null) {
      pairs.add((Icons.square_foot_rounded,
          isPlot ? 'Plot Area' : 'Carpet Area', v.area));
    }
    pairs.add((Icons.calendar_today_outlined, 'Available From',
        _fmtDate(row['available_from'])));
    return pairs;
  }

  Widget _propertyDetails(PropertyView v, Map<String, dynamic> row) {
    Widget cell((IconData, String, String)? p) {
      if (p == null) return const Expanded(child: SizedBox());
      return Expanded(
        child: Row(
          children: [
            Icon(p.$1, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.$2,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.inkSoft)),
                  Text(p.$3.isEmpty ? '—' : p.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final pairs = _detailPairs(v, row);
    final rows = <Widget>[];
    for (var i = 0; i < pairs.length; i += 2) {
      if (i > 0) {
        rows.add(const Divider(height: 1, color: AppColors.border));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          cell(pairs[i]),
          cell(i + 1 < pairs.length ? pairs[i + 1] : null),
        ]),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Property Details'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _photosVideos(PropertyView v) {
    final images = v.galleryImages;
    final tiles = <Widget>[];
    if (v.hasVideo) {
      tiles.add(_mediaTile(images.first, onTap: () => _openVideo(v),
          video: true));
    }
    for (final img in images) {
      if (tiles.length >= 3) break;
      tiles.add(_mediaTile(img,
          onTap: () => context.push('/property/${v.id}/gallery')));
    }
    while (tiles.length < 3) {
      tiles.add(const SizedBox());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Photos & Videos',
            action: 'View all (${v.photoCount}) ›',
            onTap: () => context.push('/property/${v.id}/gallery')),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(child: tiles[i]),
                if (i < 2) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _mediaTile(ImageProvider img,
      {VoidCallback? onTap, bool video = false}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
                image: img,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AppColors.primarySoft)),
            if (video) ...[
              Container(color: Colors.black.withValues(alpha: 0.3)),
              const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 34)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _landmarks() {
    Widget row(IconData icon, String name, String dist) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
              Text(dist,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Nearby Landmarks'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              row(Icons.directions_transit, 'HSR Layout Metro Station', '2.4 km'),
              row(Icons.school_outlined, 'National Public School', '1.2 km'),
              row(Icons.local_hospital_outlined, 'Manipal Hospital', '1.8 km'),
              row(Icons.storefront_outlined, 'Forum Mall', '2.1 km'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ownerCard(PropertyView v, Map<String, dynamic> row) {
    final name = v.postedBy.replaceAll(RegExp(r'\s*\(.*\)$'), '');
    final ownerId = row['owner_id'] as String?;
    final enquired =
        (ref.watch(myEnquiredIdsProvider).asData?.value ?? const <String>{})
            .contains(v.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: ownerId == null
                ? null
                : () => context.push('/owner/$ownerId', extra: v.postedBy),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(name.isNotEmpty ? name[0] : 'O',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20)),
                ),
                const SizedBox(width: 12),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.prefGreenBg,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('Verified Owner',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.prefGreen)),
                          ),
                        ],
                      ),
                      Text('View all listings',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5, color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 15, color: Color(0xFFF5A623)),
                          const SizedBox(width: 3),
                          Text('4.8 (32 reviews)',
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkSoft),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (enquired)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.prefGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 17, color: AppColors.prefGreen),
                  const SizedBox(width: 6),
                  Text('Enquiry sent · owner will reach out',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.prefGreen)),
                ],
              ),
            )
          else
            Row(
              children: [
                _contactBtn(Icons.chat_rounded, 'WhatsApp',
                    () => _whatsappOwner(v, ownerId)),
                const SizedBox(width: 8),
                _contactBtn(Icons.call_outlined, 'Call',
                    () => _callOwner(v, ownerId)),
                const SizedBox(width: 8),
                _contactBtn(Icons.mail_outline_rounded, 'Message',
                    () => _enquire(v.id, ownerId, 'message')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _contactBtn(IconData icon, String label, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  Widget _similar(PropertyView current) {
    final async = ref.watch(publishedPropertiesProvider);
    final others = (async.asData?.value ?? [])
        .map(PropertyView.new)
        .where((p) => p.id != current.id)
        .take(2)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Similar Properties', action: 'View all',
            onTap: () => context.go('/search')),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: others.map(_similarCard).toList(),
          ),
        ),
      ],
    );
  }

  Widget _similarCard(PropertyView v) {
    return GestureDetector(
      onTap: () => context.push('/property/${v.id}'),
      child: Container(
        width: 200,
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
              height: 100,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image(
                        image: v.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: AppColors.primarySoft)),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
                      radius: 13,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.favorite_border_rounded,
                          size: 14, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(v.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 10.5, color: AppColors.inkSoft)),
                  const SizedBox(height: 6),
                  Text(v.priceLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: v.priceColor)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _miniSpec(Icons.bed_outlined, v.beds),
                      const SizedBox(width: 8),
                      _miniSpec(Icons.bathtub_outlined, v.baths),
                      const SizedBox(width: 8),
                      Flexible(child: _miniSpec(Icons.crop_free_rounded, v.area)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSpec(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.inkSoft),
          const SizedBox(width: 2),
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 9.5, color: AppColors.ink)),
        ],
      );

  Widget _bottomBar(PropertyView v, Map<String, dynamic> row, bool isFav) {
    final ownerId = row['owner_id'] as String?;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: v.purpose == 'stay'
              ? _stayBookBar(v, ownerId, isFav)
              : _standardBar(v, ownerId, isFav),
        ),
      ),
    );
  }

  Widget _standardBar(PropertyView v, String? ownerId, bool isFav) {
    final visited =
        ref.watch(myVisitedIdsProvider).asData?.value ?? const <String>{};
    final hasVisit = visited.contains(v.id);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _toggleFav(v.id),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                    color: isFav ? Colors.red : null),
                const SizedBox(width: 6),
                Text(isFav ? 'Saved' : 'Save'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: hasVisit ? null : () => _scheduleVisit(v.id, ownerId),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    hasVisit
                        ? Icons.event_available_rounded
                        : Icons.calendar_today_rounded,
                    size: 18),
                const SizedBox(width: 8),
                Text(hasVisit ? 'Visit Requested' : 'Schedule Visit'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stayBookBar(PropertyView v, String? ownerId, bool isFav) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.priceShort,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              Text('per night',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _toggleFav(v.id),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(50, 48),
              padding: EdgeInsets.zero),
          child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 20,
              color: isFav ? Colors.red : AppColors.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: () => showStayBooking(context, ref, v, ownerId),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.event_available_rounded, size: 18),
                SizedBox(width: 8),
                Text('Book Now'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
