import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Wraps a `properties_home` row and exposes typed, display-ready fields.
class PropertyView {
  PropertyView(this.raw);
  final Map<String, dynamic> raw;

  String get id => (raw['id'] ?? '').toString();

  String get title {
    final t = raw['title'] as String?;
    if (t != null && t.isNotEmpty) return t;
    return '${raw['bhk'] ?? ''} ${raw['property_type'] ?? ''}'.trim();
  }

  String get purpose => (raw['purpose'] ?? '').toString();
  String get propertyType => (raw['property_type'] ?? '').toString();
  String get _type => (raw['property_type'] ?? '').toString().toLowerCase();

  bool get isPg =>
      _type.contains('coliving') ||
      _type.contains('pg') ||
      title.toLowerCase().contains('co-living');

  String get badge {
    if (purpose == 'stay') return 'STAY';
    if (isPg) return 'PG / CO-LIVING';
    if (purpose == 'sell') return 'FOR SALE';
    return 'FOR RENT';
  }

  Color get badgeColor {
    if (purpose == 'stay') return AppColors.prefBlue;
    if (isPg) return AppColors.primary;
    if (purpose == 'sell') return AppColors.prefOrange;
    return AppColors.prefGreen;
  }

  Color get priceColor => purpose == 'sell'
      ? AppColors.prefOrange
      : (purpose == 'stay' ? AppColors.prefBlue : AppColors.prefGreen);

  String get location {
    final parts = [raw['area'], raw['city']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  String get beds {
    final n = RegExp(r'\d+').firstMatch('${raw['bhk'] ?? ''}')?.group(0);
    if (n == null) return '${raw['bhk'] ?? ''}';
    return n == '1' ? '1 Bed' : '$n Beds';
  }

  String get baths {
    final b = raw['bathrooms'];
    if (b == null) return '- Baths';
    return b == 1 ? '1 Bath' : '$b Baths';
  }

  String get area {
    final a = raw['carpet_area'];
    if (a == null) return '';
    final n = a is num ? a.toInt() : a;
    return '$n sq.ft';
  }

  String get furnishing => (raw['furnishing'] ?? '').toString();

  String get priceLabel {
    final p = raw['price'];
    if (p is! num) return 'Price on request';
    final formatted = _fmt(p);
    if (purpose == 'sell') return formatted;
    final period = (raw['price_period'] ?? 'month').toString();
    return '$formatted /$period';
  }

  /// Short price for map pins (no period), e.g. "₹95 L", "₹1.25 Cr".
  String get priceShort {
    final p = raw['price'];
    return p is num ? _fmt(p) : '—';
  }

  double? get lat {
    final v = raw['latitude'];
    return v is num ? v.toDouble() : null;
  }

  double? get lng {
    final v = raw['longitude'];
    return v is num ? v.toDouble() : null;
  }

  num? get price {
    final p = raw['price'];
    return p is num ? p : null;
  }

  num? get carpetArea {
    final a = raw['carpet_area'];
    return a is num ? a : null;
  }

  String get createdAt => (raw['created_at'] ?? '').toString();

  static String _fmt(num v) {
    final n = v.toDouble();
    if (n >= 10000000) return '₹${_trim(n / 10000000)} Cr';
    if (n >= 100000) return '₹${_trim(n / 100000)} L';
    return '₹${_group(v.toInt())}';
  }

  static String _trim(double x) {
    final s = x.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  static String _group(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  List<String> get amenities {
    final a = raw['amenities'];
    return a is List ? a.map((e) => e.toString()).toList() : const [];
  }

  /// Per-type extra fields (PG sharing/food/gender, plot dimensions, …).
  Map<String, dynamic> get attributes {
    final a = raw['attributes'];
    return a is Map ? Map<String, dynamic>.from(a) : const {};
  }

  String attr(String key) => (attributes[key] ?? '').toString();

  String get sharing => attr('sharing');
  String get food => attr('food');
  String get gender => attr('gender');
  String get stayType => attr('stay_type');
  String get maxGuests => attr('max_guests');
  String get priceMonth => attr('price_month');

  /// Human-readable (label, value) rows for the type-specific detail section.
  List<(String, String)> get attributeRows {
    String v(String k) => attr(k);
    if (_type.contains('stay')) {
      final monthly = v('price_month');
      return [
        if (v('stay_type').isNotEmpty) ('Stay Type', v('stay_type')),
        if (v('max_guests').isNotEmpty) ('Max Guests', v('max_guests')),
        if (v('min_nights').isNotEmpty) ('Min Nights', v('min_nights')),
        if (v('check_in').isNotEmpty) ('Check-in', v('check_in')),
        if (v('check_out').isNotEmpty) ('Check-out', v('check_out')),
        if (monthly.isNotEmpty) ('Monthly Rate', '₹$monthly'),
      ];
    }
    if (_type.contains('pg') || _type.contains('coliving')) {
      return [
        if (v('sharing').isNotEmpty) ('Occupancy', v('sharing')),
        if (v('food').isNotEmpty) ('Food', v('food')),
        if (v('gender').isNotEmpty) ('Preferred For', v('gender')),
        if (v('gate_timing').isNotEmpty) ('Gate Timing', v('gate_timing')),
        if (v('notice_period').isNotEmpty)
          ('Notice Period', v('notice_period')),
      ];
    }
    if (_type.contains('plot')) {
      final dim = v('plot_length').isNotEmpty && v('plot_width').isNotEmpty
          ? "${v('plot_length')} × ${v('plot_width')} ft"
          : '';
      return [
        if (dim.isNotEmpty) ('Dimensions', dim),
        if (v('boundary').isNotEmpty) ('Boundary Wall', v('boundary')),
        if (v('approval').isNotEmpty) ('Approval', v('approval')),
      ];
    }
    if (_type.contains('commercial') || _type.contains('coworking')) {
      return [
        if (v('seats').isNotEmpty) ('Seats / Desks', v('seats')),
        if (v('washrooms').isNotEmpty) ('Washrooms', v('washrooms')),
        if (v('lock_in').isNotEmpty) ('Lock-in', v('lock_in')),
      ];
    }
    return [
      if (v('parking').isNotEmpty) ('Parking', v('parking')),
      if (v('balconies').isNotEmpty) ('Balconies', v('balconies')),
    ];
  }

  int get photoCount {
    final p = raw['photo_urls'];
    if (p is List && p.isNotEmpty) return p.length;
    return 1; // the cover always counts as one photo
  }

  /// Real uploaded gallery photo URLs (cover first, de-duplicated).
  List<String> get photos {
    final p = raw['photo_urls'];
    final list = p is List
        ? p.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final cover = (raw['cover_image_url'] ?? '').toString();
    if (cover.isNotEmpty && !list.contains(cover)) list.insert(0, cover);
    return list;
  }

  /// Image providers for the detail gallery — real photos, or the cover
  /// fallback when nothing was uploaded.
  List<ImageProvider> get galleryImages {
    final list = photos.map<ImageProvider>(NetworkImage.new).toList();
    return list.isEmpty ? [image] : list;
  }

  String? get videoUrl {
    final u = (raw['video_url'] ?? '').toString();
    return u.isEmpty ? null : u;
  }

  bool get hasVideo => videoUrl != null;

  /// Owner contact number for Call / WhatsApp. Uses a per-listing contact when
  /// the poster saved one, else the verified owner's number.
  String get contactPhone {
    final c = attr('contact_phone');
    return c.isNotEmpty ? c : '+91 98765 43210';
  }

  String get postedBy => (raw['posted_by'] ?? 'Owner').toString();
  String get posterTag => (raw['poster_tag'] ?? 'Verified').toString();

  String get updated {
    final c = raw['created_at'];
    if (c == null) return '';
    final dt = DateTime.tryParse(c.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return 'Updated ${diff.inDays}d ago';
    if (diff.inHours >= 1) return 'Updated ${diff.inHours}h ago';
    return 'Updated recently';
  }

  ImageProvider get image {
    final url = raw['cover_image_url'] as String?;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    if (isPg) return const AssetImage('assets/images/features.png');
    if (title.toLowerCase().contains('villa')) {
      return const AssetImage('assets/images/for_home.png');
    }
    return const AssetImage('assets/images/tellus_properity.png');
  }
}
