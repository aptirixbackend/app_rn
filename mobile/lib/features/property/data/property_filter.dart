import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'property_view.dart';

/// Transaction segment — the top-level tab in 99acres / Housing / NoBroker
/// ("I want to Buy / Rent / PG / Commercial / Plot"). Each segment scopes the
/// property types, the effective purpose and, crucially, the budget ranges.
enum Segment { all, buy, rent, stay, pg, commercial, plots }

class _Seg {
  const _Seg(this.label, this.icon, this.types, this.purpose, this.hasBhk,
      this.hasFurnishing,
      [this.hasPgFields = false, this.hasStayFields = false]);
  final String label;
  final IconData icon;
  final List<String> types; // property_type values in this segment
  final String? purpose; // fixed purpose ('rent'/'sell'/'stay'); null = none
  final bool hasBhk;
  final bool hasFurnishing;
  final bool hasPgFields; // sharing / food / gender (PG segment)
  final bool hasStayFields; // stay type / guests (Stay segment)
}

const _kAllTypes = [
  'Apartment',
  'Villa',
  'Independent House',
  'Stay',
  'Coliving',
  'PG',
  'Commercial',
  'Coworking',
  'Plot',
];

const _segments = <Segment, _Seg>{
  Segment.all: _Seg('All', Icons.grid_view_rounded, _kAllTypes, null, false,
      false),
  Segment.buy: _Seg('Buy', Icons.sell_outlined,
      ['Apartment', 'Villa', 'Independent House'], 'sell', true, true),
  Segment.rent: _Seg('Rent', Icons.vpn_key_outlined,
      ['Apartment', 'Villa', 'Independent House'], 'rent', true, true),
  Segment.stay: _Seg('Stay', Icons.night_shelter_outlined, ['Stay'], 'stay',
      false, false, false, true),
  Segment.pg: _Seg('PG / Co-living', Icons.single_bed_outlined,
      ['PG', 'Coliving'], 'rent', false, false, true),
  Segment.commercial: _Seg('Commercial', Icons.business_center_outlined,
      ['Commercial', 'Coworking'], null, false, true),
  Segment.plots: _Seg('Plots / Land', Icons.landscape_outlined, ['Plot'],
      'sell', false, false),
};

// Budget ranges are per transaction — rent is priced monthly, sale in lakhs/cr,
// PG cheaper, commercial higher. (label, min, max) with null = open-ended.
const _rentBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹10K', null, 10000),
  ('₹10K – ₹15K', 10000, 15000),
  ('₹15K – ₹25K', 15000, 25000),
  ('₹25K – ₹40K', 25000, 40000),
  ('₹40K – ₹60K', 40000, 60000),
  ('₹60K – ₹1L', 60000, 100000),
  ('₹1L +', 100000, null),
];
const _buyBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹40L', null, 4000000),
  ('₹40L – ₹60L', 4000000, 6000000),
  ('₹60L – ₹80L', 6000000, 8000000),
  ('₹80L – ₹1Cr', 8000000, 10000000),
  ('₹1Cr – ₹1.5Cr', 10000000, 15000000),
  ('₹1.5Cr – ₹2Cr', 15000000, 20000000),
  ('₹2Cr +', 20000000, null),
];
const _pgBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹7K', null, 7000),
  ('₹7K – ₹10K', 7000, 10000),
  ('₹10K – ₹13K', 10000, 13000),
  ('₹13K – ₹18K', 13000, 18000),
  ('₹18K +', 18000, null),
];
const _commRentBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹50K', null, 50000),
  ('₹50K – ₹1L', 50000, 100000),
  ('₹1L – ₹2L', 100000, 200000),
  ('₹2L – ₹5L', 200000, 500000),
  ('₹5L +', 500000, null),
];
const _commBuyBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹1Cr', null, 10000000),
  ('₹1Cr – ₹2Cr', 10000000, 20000000),
  ('₹2Cr – ₹4Cr', 20000000, 40000000),
  ('₹4Cr – ₹7Cr', 40000000, 70000000),
  ('₹7Cr +', 70000000, null),
];
const _plotBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹50L', null, 5000000),
  ('₹50L – ₹1Cr', 5000000, 10000000),
  ('₹1Cr – ₹2Cr', 10000000, 20000000),
  ('₹2Cr – ₹3Cr', 20000000, 30000000),
  ('₹3Cr +', 30000000, null),
];
// Stay budgets are per night.
const _stayBuckets = <(String, num?, num?)>[
  ('Any', null, null),
  ('< ₹1K', null, 1000),
  ('₹1K – ₹2K', 1000, 2000),
  ('₹2K – ₹3.5K', 2000, 3500),
  ('₹3.5K – ₹6K', 3500, 6000),
  ('₹6K +', 6000, null),
];
const _noBuckets = <(String, num?, num?)>[('Any', null, null)];

const _bhkOptions = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK', '5+ BHK'];
const _furnishingOptions = ['Fully Furnished', 'Semi Furnished', 'Unfurnished'];
const _sharingOptions = [
  'Single Sharing',
  'Double Sharing',
  'Triple Sharing',
  'Four Sharing',
  'Private Room',
];
const _foodOptions = ['With Food', 'Without Food'];
const _genderOptions = ['Men', 'Women', 'Co-ed'];
const _stayTypeOptions = [
  'Entire House',
  'Private Room',
  'Shared Room',
  'Studio',
];
const _guestOptions = ['1', '2', '3', '4+'];

const kSortOptions = <(String, String)>[
  ('relevance', 'Relevance'),
  ('price_asc', 'Price: Low to High'),
  ('price_desc', 'Price: High to Low'),
  ('newest', 'Newest First'),
  ('area_desc', 'Area: Largest First'),
];

List<(String, num?, num?)> _bucketsFor(Segment seg, String commercialPurpose) {
  switch (seg) {
    case Segment.buy:
      return _buyBuckets;
    case Segment.rent:
      return _rentBuckets;
    case Segment.pg:
      return _pgBuckets;
    case Segment.plots:
      return _plotBuckets;
    case Segment.commercial:
      return commercialPurpose == 'sell' ? _commBuyBuckets : _commRentBuckets;
    case Segment.stay:
      return _stayBuckets;
    case Segment.all:
      return _noBuckets;
  }
}

String typeDisplay(String t) {
  switch (t) {
    case 'Independent House':
      return 'Ind. House';
    case 'Coliving':
      return 'Co-living';
    case 'Coworking':
      return 'Co-working';
    default:
      return t;
  }
}

const _sentinel = Object();

/// Immutable filter/sort state, shared by Search, Map and Home categories.
class PropertyFilter {
  const PropertyFilter({
    this.segment = Segment.all,
    this.commercialPurpose = 'rent',
    this.priceIdx = 0,
    this.types = const {},
    this.bhks = const {},
    this.furnishing,
    this.sharing = const {},
    this.food,
    this.gender,
    this.stayType = const {},
    this.guests,
    this.areas = const {},
    this.sort = 'relevance',
  });

  /// Build a filter scoped to a single property type (Home category taps).
  factory PropertyFilter.ofType(String t) {
    final seg = _segments.entries
        .firstWhere(
          (e) => e.key != Segment.all && e.value.types.contains(t),
          orElse: () => const MapEntry(Segment.all, _Seg('', Icons.abc, [],
              null, false, false)),
        )
        .key;
    // Apartment/Villa/House exist in both buy & rent → keep them under "All"
    // so the tap shows every matching listing regardless of purpose.
    final scoped = (seg == Segment.pg ||
            seg == Segment.commercial ||
            seg == Segment.plots ||
            seg == Segment.stay)
        ? seg
        : Segment.all;
    return PropertyFilter(segment: scoped, types: {t});
  }

  final Segment segment;
  final String commercialPurpose; // 'rent'|'sell' — only used for commercial
  final int priceIdx;
  final Set<String> types;
  final Set<String> bhks;
  final String? furnishing;
  final Set<String> sharing; // PG occupancy (multi)
  final String? food; // PG: 'With Food' | 'Without Food'
  final String? gender; // PG: 'Men' | 'Women' | 'Co-ed'
  final Set<String> stayType; // Stay: Entire House / Private Room / … (multi)
  final String? guests; // Stay: min guests ('1'..'4+')
  final Set<String> areas; // localities within the city (multi-select)
  final String sort;

  _Seg get _cfg => _segments[segment]!;
  List<(String, num?, num?)> get buckets =>
      _bucketsFor(segment, commercialPurpose);
  bool get hasBudget => buckets.length > 1;

  String? get effectivePurpose =>
      segment == Segment.commercial ? commercialPurpose : _cfg.purpose;

  bool get hasFilters =>
      segment != Segment.all ||
      priceIdx != 0 ||
      types.isNotEmpty ||
      bhks.isNotEmpty ||
      furnishing != null ||
      sharing.isNotEmpty ||
      food != null ||
      gender != null ||
      stayType.isNotEmpty ||
      guests != null ||
      areas.isNotEmpty;

  // ---- labels for header chips / titles ----------------------------------
  String get segmentLabel =>
      segment == Segment.all ? 'Buy / Rent' : _cfg.label;
  String get priceLabel =>
      priceIdx == 0 ? 'Budget' : buckets[priceIdx.clamp(0, buckets.length - 1)].$1;
  String? get type => types.isEmpty
      ? null
      : (types.length == 1 ? typeDisplay(types.first) : '${types.length} Types');
  String get screenTitle {
    if (types.length == 1) return '${typeDisplay(types.first)}s';
    if (segment != Segment.all) return _cfg.label;
    return 'All Properties';
  }

  PropertyFilter copyWith({
    Segment? segment,
    String? commercialPurpose,
    int? priceIdx,
    Set<String>? types,
    Set<String>? bhks,
    Object? furnishing = _sentinel,
    Set<String>? sharing,
    Object? food = _sentinel,
    Object? gender = _sentinel,
    Set<String>? stayType,
    Object? guests = _sentinel,
    Set<String>? areas,
    String? sort,
  }) =>
      PropertyFilter(
        segment: segment ?? this.segment,
        commercialPurpose: commercialPurpose ?? this.commercialPurpose,
        priceIdx: priceIdx ?? this.priceIdx,
        types: types ?? this.types,
        bhks: bhks ?? this.bhks,
        furnishing:
            furnishing == _sentinel ? this.furnishing : furnishing as String?,
        sharing: sharing ?? this.sharing,
        food: food == _sentinel ? this.food : food as String?,
        gender: gender == _sentinel ? this.gender : gender as String?,
        stayType: stayType ?? this.stayType,
        guests: guests == _sentinel ? this.guests : guests as String?,
        areas: areas ?? this.areas,
        sort: sort ?? this.sort,
      );

  PropertyFilter withSort(String s) => copyWith(sort: s);
  PropertyFilter cleared() => PropertyFilter(sort: sort);

  List<PropertyView> apply(List<PropertyView> list) {
    final segTypes = _cfg.types.map((e) => e.toLowerCase()).toSet();
    final selTypes = types.map((e) => e.toLowerCase()).toSet();
    final b = buckets;
    final (_, min, max) = b[priceIdx.clamp(0, b.length - 1)];
    final purpose = effectivePurpose;

    var out = list.where((v) {
      final vt = v.propertyType.toLowerCase();
      if (segment != Segment.all && !segTypes.contains(vt)) return false;
      if (selTypes.isNotEmpty && !selTypes.contains(vt)) return false;
      if (purpose != null && v.purpose != purpose) return false;
      final p = v.price ?? 0;
      if (min != null && p < min) return false;
      if (max != null && p > max) return false;
      if (bhks.isNotEmpty && !_bhkMatches(v)) return false;
      if (furnishing != null && v.furnishing != furnishing) return false;
      if (sharing.isNotEmpty &&
          !sharing.map((e) => e.toLowerCase()).contains(v.sharing.toLowerCase())) {
        return false;
      }
      if (food != null && v.food != food) return false;
      if (gender != null && v.gender != gender) return false;
      if (stayType.isNotEmpty &&
          !stayType
              .map((e) => e.toLowerCase())
              .contains(v.stayType.toLowerCase())) {
        return false;
      }
      if (guests != null) {
        final want = int.tryParse(guests!.replaceAll('+', '')) ?? 0;
        final have = int.tryParse(v.maxGuests) ?? 0;
        if (have < want) return false;
      }
      if (areas.isNotEmpty &&
          !areas
              .map((e) => e.toLowerCase())
              .contains((v.raw['area'] ?? '').toString().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    switch (sort) {
      case 'price_asc':
        out.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
      case 'price_desc':
        out.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
      case 'newest':
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'area_desc':
        out.sort((a, b) => (b.carpetArea ?? 0).compareTo(a.carpetArea ?? 0));
    }
    return out;
  }

  bool _bhkMatches(PropertyView v) {
    final raw = '${v.raw['bhk'] ?? ''}'.toLowerCase();
    final have = int.tryParse(RegExp(r'\d+').firstMatch(raw)?.group(0) ?? '');
    for (final sel in bhks) {
      final s = sel.toLowerCase();
      if (s.contains('rk')) {
        if (raw.contains('rk') || raw.contains('studio')) return true;
      } else if (s.startsWith('5')) {
        if (have != null && have >= 5) return true;
      } else {
        final want =
            int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '');
        if (want != null && want == have) return true;
      }
    }
    return false;
  }

  /// (label, filterWithThatChipRemoved) for the active-filter bar.
  List<(String, PropertyFilter)> activeChips() {
    final out = <(String, PropertyFilter)>[];
    if (segment != Segment.all) {
      out.add((_cfg.label, cleared()));
    }
    if (priceIdx != 0) {
      out.add((buckets[priceIdx].$1, copyWith(priceIdx: 0)));
    }
    for (final t in types) {
      out.add((typeDisplay(t), copyWith(types: {...types}..remove(t))));
    }
    for (final b in bhks) {
      out.add((b, copyWith(bhks: {...bhks}..remove(b))));
    }
    if (furnishing != null) {
      out.add((furnishing!, copyWith(furnishing: null)));
    }
    for (final s in sharing) {
      out.add((s, copyWith(sharing: {...sharing}..remove(s))));
    }
    if (food != null) out.add((food!, copyWith(food: null)));
    if (gender != null) out.add(('$gender Only', copyWith(gender: null)));
    for (final s in stayType) {
      out.add((s, copyWith(stayType: {...stayType}..remove(s))));
    }
    if (guests != null) out.add(('$guests Guests', copyWith(guests: null)));
    for (final a in areas) {
      out.add((a, copyWith(areas: {...areas}..remove(a))));
    }
    return out;
  }
}

Widget _handle() => Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
          color: AppColors.boxBorder, borderRadius: BorderRadius.circular(3)),
    );

/// Sort bottom sheet — returns the chosen sort key (or null if dismissed).
Future<String?> showSortSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          for (final o in kSortOptions)
            ListTile(
              title: Text(o.$2,
                  style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight:
                          current == o.$1 ? FontWeight.w600 : FontWeight.w400,
                      color:
                          current == o.$1 ? AppColors.primary : AppColors.ink)),
              trailing: current == o.$1
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, o.$1),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Full filter bottom sheet (99acres / Housing style) — returns the new filter
/// on Apply (or null if dismissed).
Future<PropertyFilter?> showFilterSheet(
    BuildContext context, PropertyFilter current,
    {List<String> localities = const []}) {
  var seg = current.segment;
  var commPurpose = current.commercialPurpose;
  var priceIdx = current.priceIdx;
  var types = {...current.types};
  var bhks = {...current.bhks};
  String? furnishing = current.furnishing;
  var sharing = {...current.sharing};
  String? food = current.food;
  String? gender = current.gender;
  var stayType = {...current.stayType};
  String? guests = current.guests;
  var areas = {...current.areas};

  return showModalBottomSheet<PropertyFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final cfg = _segments[seg]!;
          final buckets = _bucketsFor(seg, commPurpose);

          Widget pill(String label, bool sel, VoidCallback onTap,
                  {IconData? icon}) =>
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primarySoft : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: sel ? 1.4 : 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon,
                            size: 15,
                            color: sel ? AppColors.primary : AppColors.inkSoft),
                        const SizedBox(width: 6),
                      ],
                      Text(label,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: sel ? AppColors.primary : AppColors.ink)),
                    ],
                  ),
                ),
              );

          Widget section(String title, List<Widget> chips) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                  const SizedBox(height: 18),
                ],
              );

          void selectSeg(Segment s) => setSheet(() {
                seg = s;
                priceIdx = 0;
                types = {};
                bhks = {};
                furnishing = null;
                sharing = {};
                food = null;
                gender = null;
                stayType = {};
                guests = null;
                commPurpose = 'rent';
              });

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _handle()),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filters',
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      GestureDetector(
                        onTap: () => setSheet(() {
                          seg = Segment.all;
                          priceIdx = 0;
                          types = {};
                          bhks = {};
                          furnishing = null;
                          sharing = {};
                          food = null;
                          gender = null;
                          stayType = {};
                          guests = null;
                          areas = {};
                          commPurpose = 'rent';
                        }),
                        child: Text('Reset',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ---- Segment tabs ------------------------------------
                  Text('I want to',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final e in _segments.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: pill(e.value.label, seg == e.key,
                                () => selectSeg(e.key),
                                icon: e.value.icon),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ---- Commercial rent/buy toggle ----------------------
                  if (seg == Segment.commercial)
                    section('Transaction', [
                      pill('Lease / Rent', commPurpose == 'rent',
                          () => setSheet(() {
                                commPurpose = 'rent';
                                priceIdx = 0;
                              })),
                      pill('Buy', commPurpose == 'sell',
                          () => setSheet(() {
                                commPurpose = 'sell';
                                priceIdx = 0;
                              })),
                    ]),

                  // ---- Budget (contextual) -----------------------------
                  if (buckets.length > 1)
                    section('Budget', [
                      for (var i = 0; i < buckets.length; i++)
                        pill(buckets[i].$1, priceIdx == i,
                            () => setSheet(() => priceIdx = i)),
                    ])
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                          'Pick Buy, Rent, PG, Commercial or Plots to set a budget.',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5, color: AppColors.inkSoft)),
                    ),

                  // ---- Locality (multi-select within the city) ---------
                  if (localities.isNotEmpty)
                    section('Locality', [
                      for (final a in localities)
                        pill(a, areas.contains(a), () {
                          setSheet(() => areas.contains(a)
                              ? areas.remove(a)
                              : areas.add(a));
                        }),
                    ]),

                  // ---- Property Type (multi) ---------------------------
                  if (cfg.types.length > 1)
                    section('Property Type', [
                      for (final t in cfg.types)
                        pill(typeDisplay(t), types.contains(t), () {
                          setSheet(() => types.contains(t)
                              ? types.remove(t)
                              : types.add(t));
                        }),
                    ]),

                  // ---- BHK (residential) -------------------------------
                  if (cfg.hasBhk)
                    section('Bedrooms', [
                      for (final b in _bhkOptions)
                        pill(b, bhks.contains(b), () {
                          setSheet(() =>
                              bhks.contains(b) ? bhks.remove(b) : bhks.add(b));
                        }),
                    ]),

                  // ---- Furnishing --------------------------------------
                  if (cfg.hasFurnishing)
                    section('Furnishing', [
                      pill('Any', furnishing == null,
                          () => setSheet(() => furnishing = null)),
                      for (final f in _furnishingOptions)
                        pill(f, furnishing == f,
                            () => setSheet(() => furnishing = f)),
                    ]),

                  // ---- PG: occupancy / food / gender -------------------
                  if (cfg.hasPgFields) ...[
                    section('Occupancy / Sharing', [
                      for (final s in _sharingOptions)
                        pill(s, sharing.contains(s), () {
                          setSheet(() => sharing.contains(s)
                              ? sharing.remove(s)
                              : sharing.add(s));
                        }),
                    ]),
                    section('Food', [
                      pill('Any', food == null,
                          () => setSheet(() => food = null)),
                      for (final f in _foodOptions)
                        pill(f, food == f, () => setSheet(() => food = f)),
                    ]),
                    section('Preferred For', [
                      pill('Anyone', gender == null,
                          () => setSheet(() => gender = null)),
                      for (final g in _genderOptions)
                        pill(g, gender == g, () => setSheet(() => gender = g)),
                    ]),
                  ],

                  // ---- Stay: type / guests -----------------------------
                  if (cfg.hasStayFields) ...[
                    section('Stay Type', [
                      for (final s in _stayTypeOptions)
                        pill(s, stayType.contains(s), () {
                          setSheet(() => stayType.contains(s)
                              ? stayType.remove(s)
                              : stayType.add(s));
                        }),
                    ]),
                    section('Guests', [
                      pill('Any', guests == null,
                          () => setSheet(() => guests = null)),
                      for (final g in _guestOptions)
                        pill('$g Guests', guests == g,
                            () => setSheet(() => guests = g)),
                    ]),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        ctx,
                        PropertyFilter(
                          segment: seg,
                          commercialPurpose: commPurpose,
                          priceIdx: priceIdx,
                          types: types,
                          bhks: bhks,
                          furnishing: furnishing,
                          sharing: sharing,
                          food: food,
                          gender: gender,
                          stayType: stayType,
                          guests: guests,
                          areas: areas,
                          sort: current.sort,
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
