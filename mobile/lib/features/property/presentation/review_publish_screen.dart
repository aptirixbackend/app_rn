import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import 'widgets/posting_widgets.dart';

class ReviewPublishScreen extends ConsumerStatefulWidget {
  const ReviewPublishScreen({super.key, this.propertyId});
  final String? propertyId;

  @override
  ConsumerState<ReviewPublishScreen> createState() =>
      _ReviewPublishScreenState();
}

class _ReviewPublishScreenState extends ConsumerState<ReviewPublishScreen> {
  Map<String, dynamic>? _draft;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(propertyRepositoryProvider);
      final draft = await repo.getLatestDraft();
      final profile = await repo.getMyProfile();
      if (mounted) {
        setState(() {
          _draft = draft;
          _profile = profile;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      if (widget.propertyId != null) {
        await ref.read(propertyRepositoryProvider).publish(widget.propertyId!);
      }
      ref
        ..invalidate(publishedPropertiesProvider)
        ..invalidate(myPropertiesProvider);
    } catch (_) {
      // ignore in preview
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Property published!')),
      );
      context.go('/home');
    }
  }

  String _money(num v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Fall back to sample data so the screen is complete before real data exists.
    final d = _draft ??
        const {
          'bhk': '2 BHK',
          'property_type': 'Apartment',
          'purpose': 'Rent',
          'bathrooms': 2,
          'carpet_area': 950,
          'area': 'HSR Layout',
          'city': 'Bengaluru',
          'price': 25000,
          'price_period': 'month',
          'photo_urls': [],
        };
    final p = _profile ??
        const {
          'first_name': 'Sneha',
          'last_name': 'Reddy',
          'phone': '+91 98765 43210',
          'email': 'sneha.reddy@email.com',
        };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  PostingProgressBar(
                      step: 6,
                      onBack: () => context.go('/post-property/media')),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 16),
                          _successBanner(),
                          const SizedBox(height: 16),
                          _previewCard(d),
                          const SizedBox(height: 16),
                          _detailsCard(d),
                          const SizedBox(height: 16),
                          _postedByCard(p),
                          const SizedBox(height: 16),
                          _whatsNextCard(),
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
              Text('Review & publish',
                  style: GoogleFonts.poppins(
                      fontSize: 23, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Almost there! Review your details\nbefore publishing',
                  style: GoogleFonts.poppins(
                      fontSize: 13, height: 1.35, color: AppColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Image.asset('assets/images/review_page.png',
            width: 104, fit: BoxFit.contain),
      ],
    );
  }

  Widget _successBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.prefGreenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Great! Your property is ready to be published.',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green)),
                const SizedBox(height: 2),
                Text('Please review all the details before you go live.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _cardTitle(String title, VoidCallback onEdit) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 13.5, fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: onEdit,
            child: Text('Edit',
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      );

  Widget _previewCard(Map<String, dynamic> d) {
    final bhk = (d['bhk'] ?? '').toString();
    final type = (d['property_type'] ?? '').toString();
    final purpose = (d['purpose'] ?? '').toString();
    final title = '$bhk $type for $purpose'.trim();
    final area = d['area']?.toString();
    final city = d['city']?.toString();
    final location =
        [area, city, 'Karnataka'].where((e) => e != null && e != '').join(', ');
    final baths = d['bathrooms']?.toString() ?? '-';
    final carpet = d['carpet_area'];
    final price = d['price'];
    final period = (d['price_period'] ?? 'month').toString();
    final photos = (d['photo_urls'] as List?) ?? const [];
    final cover = d['cover_image_url']?.toString();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Property Preview', () => context.go('/post-property')),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 108,
                      height: 96,
                      child: cover != null
                          ? Image.network(cover, fit: BoxFit.cover)
                          : Image.asset('assets/images/home_signup.png',
                              fit: BoxFit.cover),
                    ),
                    if (photos.isNotEmpty)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('+${photos.length}',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(purpose,
                              style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(location,
                        style: GoogleFonts.poppins(
                            fontSize: 11.5, color: AppColors.inkSoft)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _spec(Icons.bed_outlined, bhk),
                        _spec(Icons.bathtub_outlined, '$baths Baths'),
                        if (carpet != null)
                          _spec(Icons.square_foot_rounded, '$carpet sq.ft'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      price != null
                          ? _priceStr(price as num, period)
                          : 'Price not set',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spec(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.inkSoft),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11.5, color: AppColors.ink)),
      ],
    );
  }

  String _priceStr(num price, String period) {
    final base = '₹${_money(price)}';
    return (period == 'total' || period.isEmpty) ? base : '$base /$period';
  }

  String? _rupee(Object? v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    final n = num.tryParse(s);
    return n != null ? '₹${_money(n)}' : s;
  }

  /// Full listing summary — pricing + type-specific details before publish.
  Widget _detailsCard(Map<String, dynamic> d) {
    final rows = <(String, String)>[];
    void add(String label, Object? val) {
      final s = (val ?? '').toString().trim();
      if (s.isNotEmpty) rows.add((label, s));
    }

    final attrs = d['attributes'] is Map
        ? Map<String, dynamic>.from(d['attributes'] as Map)
        : const <String, dynamic>{};

    add('Property Type', d['property_type']);
    add('Configuration', d['bhk']);
    add('Carpet Area',
        d['carpet_area'] != null ? '${d['carpet_area']} sq.ft' : null);
    add('Furnishing', d['furnishing']);
    if (d['floor_number'] != null) {
      add('Floor', '${d['floor_number']} of ${d['total_floors'] ?? '-'}');
    }
    add('Facing', d['facing']);
    add('Available From', d['available_from']);

    final price = d['price'];
    final period = (d['price_period'] ?? '').toString();
    if (price is num) add('Price', _priceStr(price, period));
    add('Monthly Rate', _rupee(attrs['price_month']));
    add('Security Deposit', _rupee(attrs['deposit']));
    add('Maintenance', _rupee(attrs['maintenance']));
    add('Cleaning Fee', _rupee(attrs['cleaning_fee']));
    if (attrs['negotiable'] == true) add('Negotiable', 'Yes');

    // type-specific
    add('Occupancy', attrs['sharing']);
    add('Food', attrs['food']);
    add('Preferred For', attrs['gender']);
    add('Gate Timing', attrs['gate_timing']);
    add('Stay Type', attrs['stay_type']);
    add('Max Guests', attrs['max_guests']);
    add('Min Nights', attrs['min_nights']);
    if (attrs['plot_length'] != null && attrs['plot_width'] != null) {
      add('Plot Size', '${attrs['plot_length']} × ${attrs['plot_width']} ft');
    }
    add('Approval', attrs['approval']);
    add('Seats / Desks', attrs['seats']);
    add('Lock-in', attrs['lock_in']);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Listing Details', () => context.go('/post-property')),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(rows[i].$1,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.inkSoft)),
                  ),
                  Expanded(
                    child: Text(rows[i].$2,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _postedByCard(Map<String, dynamic> p) {
    final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final phone = p['phone']?.toString() ?? '';
    final email = p['email']?.toString() ?? '';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Posted By', () => context.go('/onboarding/about-you')),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('$name (Owner)',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.prefGreenBg,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('Verified',
                              style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.green)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _contactRow(Icons.phone_outlined, phone),
                    const SizedBox(height: 3),
                    _contactRow(Icons.mail_outline_rounded, email),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.inkSoft),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.inkSoft)),
        ),
      ],
    );
  }

  Widget _whatsNextCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's Next?",
              style: GoogleFonts.poppins(
                  fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _nextRow(Icons.insights_rounded, 'Get better visibility',
              "We'll promote your listing to the right audience."),
          const SizedBox(height: 12),
          _nextRow(Icons.forum_rounded, 'Receive inquiries',
              'Buyers & tenants will contact you directly.'),
          const SizedBox(height: 12),
          _nextRow(Icons.dashboard_customize_rounded, 'Manage easily',
              'Track leads and manage your property from dashboard.'),
        ],
      ),
    );
  }

  Widget _nextRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, height: 1.3, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.rocket_launch_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Publish Property'),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              ref.invalidate(myPropertiesProvider);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                    content:
                        Text('Saved to drafts — resume from My Properties')));
              context.go('/my-properties');
            },
            child: Text('Save as Draft',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          const SecureNote(text: 'You can edit details anytime from dashboard'),
        ],
      ),
    );
  }
}
