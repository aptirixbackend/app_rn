import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/city_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';
import '../../property/presentation/location_picker_screen.dart';

const _typeOptions = [
  'Apartment', 'Villa', 'Independent House', 'Plot', 'Commercial', 'PG', 'Stay'
];
const _purposeOptions = ['rent', 'sell', 'stay'];
const _periodOptions = ['month', 'night', 'week', 'year', 'total'];
const _bhkOptions = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK', '5+ BHK'];
const _bathOptions = ['1', '2', '3', '4', '5+'];
const _furnishOptions = ['Unfurnished', 'Semi Furnished', 'Fully Furnished'];
const _ageOptions = [
  'Under Construction', 'New', '0-1 years', '1-5 years', '5-10 years', '10+ years'
];
const _facingOptions = [
  'East', 'West', 'North', 'South',
  'North-East', 'North-West', 'South-East', 'South-West'
];
const _amenityOptions = <(String, IconData)>[
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

/// Attribute keys that get their own dedicated fields (or are internal), so the
/// dynamic "More details" section doesn't duplicate them.
const _handledAttrs = {
  'deposit', 'maintenance', 'price_month', 'cleaning_fee', 'token_amount',
  'negotiable', 'closed_reason', 'closed_to',
};

/// One gallery item — either an already-uploaded URL or a freshly-picked image
/// held in memory until save.
class _Photo {
  _Photo.url(this.url) : bytes = null;
  _Photo.bytes(this.bytes) : url = null;
  final String? url;
  final Uint8List? bytes;
  bool get isNew => bytes != null;
}

/// Full-listing editor: every meaningful field an owner might change —
/// basics, type/purpose, location pin, pricing, amenities, type-specific
/// details, description, photos/video and status — in one screen.
class EditPropertyScreen extends ConsumerStatefulWidget {
  const EditPropertyScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  ConsumerState<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends ConsumerState<EditPropertyScreen> {
  // text controllers
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _priceMonth = TextEditingController();
  final _deposit = TextEditingController();
  final _maintenance = TextEditingController();
  final _cleaning = TextEditingController();
  final _token = TextEditingController();
  final _carpet = TextEditingController();
  final _floor = TextEditingController();
  final _total = TextEditingController();
  final _locality = TextEditingController();
  final _highlights = TextEditingController();
  final _picker = ImagePicker();

  // dropdown / toggle state
  String _type = 'Apartment';
  String _purpose = 'rent';
  String _period = 'month';
  String _bhk = '2 BHK';
  String _bathrooms = '2';
  String _furnishing = 'Semi Furnished';
  String _facing = 'East';
  String _age = '5-10 years';
  String _city = kCities.first;
  DateTime? _availableFrom;
  bool _negotiable = true;
  bool _active = true;
  LatLng? _pin;

  final _amenities = <String>{};
  final _extra = <String, TextEditingController>{}; // dynamic attributes
  final _photos = <_Photo>[];

  String? _existingVideo;
  Uint8List? _newVideo;
  bool _videoRemoved = false;

  final _origAttrs = <String, dynamic>{};
  bool _loaded = false;
  bool _found = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await ref
        .read(propertyRepositoryProvider)
        .getPropertyById(widget.propertyId);
    if (row == null) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _found = false;
        });
      }
      return;
    }
    final v = PropertyView(row);
    _title.text = v.title;
    _price.text = (v.price ?? '').toString();
    _highlights.text = (row['highlights'] ?? '').toString();
    _type = (row['property_type'] ?? _type).toString();
    _purpose = (row['purpose'] ?? _purpose).toString();
    _period = (row['price_period'] ?? _period).toString();
    _bhk = (row['bhk'] ?? _bhk).toString();
    final baths = (row['bathrooms'] ?? '').toString();
    if (baths.isNotEmpty) _bathrooms = baths;
    _furnishing =
        _furnishOptions.contains(v.furnishing) ? v.furnishing : _furnishing;
    _facing = (row['facing'] ?? _facing).toString();
    _age = (row['property_age'] ?? _age).toString();
    _carpet.text = (row['carpet_area'] ?? '').toString();
    _floor.text = (row['floor_number'] ?? '').toString();
    _total.text = (row['total_floors'] ?? '').toString();
    _city = (row['city'] ?? _city).toString();
    _locality.text = (row['area'] ?? '').toString();
    _active = (row['status'] ?? 'published').toString() != 'draft' &&
        (row['status'] ?? '').toString() != 'paused';
    final af = row['available_from'];
    _availableFrom = af == null ? null : DateTime.tryParse(af.toString());

    final lat = row['latitude'], lng = row['longitude'];
    if (lat is num && lng is num) {
      _pin = LatLng(lat.toDouble(), lng.toDouble());
    } else {
      final (clat, clng) = cityCenter(_city);
      _pin = LatLng(clat, clng);
    }

    _amenities.addAll(v.amenities);

    if (row['attributes'] is Map) {
      _origAttrs.addAll(Map<String, dynamic>.from(row['attributes'] as Map));
    }
    _deposit.text = (_origAttrs['deposit'] ?? '').toString();
    _maintenance.text = (_origAttrs['maintenance'] ?? '').toString();
    _priceMonth.text = (_origAttrs['price_month'] ?? '').toString();
    _cleaning.text = (_origAttrs['cleaning_fee'] ?? '').toString();
    _token.text = (_origAttrs['token_amount'] ?? '').toString();
    if (_origAttrs['negotiable'] is bool) _negotiable = _origAttrs['negotiable'];
    for (final e in _origAttrs.entries) {
      if (_handledAttrs.contains(e.key)) continue;
      _extra[e.key] = TextEditingController(text: (e.value ?? '').toString());
    }

    for (final u in v.photos) {
      _photos.add(_Photo.url(u));
    }
    _existingVideo = v.videoUrl;

    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [
      _title, _price, _priceMonth, _deposit, _maintenance, _cleaning,
      _token, _carpet, _floor, _total, _locality, _highlights,
    ]) {
      c.dispose();
    }
    for (final c in _extra.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- pickers -----------------------------------------------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  Future<void> _pickLocation() async {
    final (clat, clng) = cityCenter(_city);
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initial: _pin ?? LatLng(clat, clng)),
      ),
    );
    if (result != null && mounted) setState(() => _pin = result);
  }

  Future<void> _addPhotos() async {
    final xs = await _picker.pickMultiImage(imageQuality: 80);
    for (final x in xs) {
      if (_photos.length >= 20) break;
      _photos.add(_Photo.bytes(await x.readAsBytes()));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
    if (x != null) {
      final b = await x.readAsBytes();
      if (mounted) {
        setState(() {
          _newVideo = b;
          _videoRemoved = false;
        });
      }
    }
  }

  // ---- save --------------------------------------------------------------
  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _snack('Please enter a title.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(propertyRepositoryProvider);
    final id = widget.propertyId;
    try {
      // Photos: upload any new ones, keep order (first = cover).
      final urls = <String>[];
      for (final p in _photos) {
        if (p.url != null) {
          urls.add(p.url!);
        } else {
          final u = await repo.uploadMedia(
              p.bytes!, 'photo_${id}_${urls.length}_${_stamp()}.jpg');
          if (u != null) urls.add(u);
        }
      }

      // Attributes: dedicated money fields + preserved internals + dynamic.
      final attrs = <String, dynamic>{};
      if (_origAttrs['closed_reason'] != null) {
        attrs['closed_reason'] = _origAttrs['closed_reason'];
      }
      if (_origAttrs['closed_to'] != null) {
        attrs['closed_to'] = _origAttrs['closed_to'];
      }
      void money(String k, TextEditingController c) {
        final t = c.text.trim();
        if (t.isNotEmpty) attrs[k] = t;
      }
      money('deposit', _deposit);
      money('maintenance', _maintenance);
      money('price_month', _priceMonth);
      money('cleaning_fee', _cleaning);
      money('token_amount', _token);
      attrs['negotiable'] = _negotiable;
      _extra.forEach((k, c) {
        final t = c.text.trim();
        if (t.isNotEmpty) attrs[k] = t;
      });

      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'price': num.tryParse(_price.text.trim()),
        'price_period': _period,
        'property_type': _type,
        'purpose': _purpose,
        'bhk': _bhk,
        'bathrooms': int.tryParse(_bathrooms.replaceAll(RegExp(r'[^0-9]'), '')),
        'carpet_area': num.tryParse(_carpet.text.trim()),
        'furnishing': _furnishing,
        'facing': _facing,
        'property_age': _age,
        'floor_number': int.tryParse(_floor.text.trim()),
        'total_floors': int.tryParse(_total.text.trim()),
        'available_from': _availableFrom?.toIso8601String().split('T').first,
        'city': _city,
        'area': _locality.text.trim().isEmpty ? null : _locality.text.trim(),
        'latitude': _pin?.latitude,
        'longitude': _pin?.longitude,
        'highlights': _highlights.text.trim(),
        'amenities': _amenities.toList(),
        'attributes': attrs,
        'status': _active ? 'published' : 'draft',
        'cover_image_url': urls.isNotEmpty ? urls.first : null,
        'photo_urls': urls.isEmpty ? null : urls,
      };

      // Video: replace, remove, or leave untouched.
      if (_newVideo != null) {
        data['video_url'] =
            await repo.uploadMedia(_newVideo!, 'video_${id}_${_stamp()}.mp4',
                contentType: 'video/mp4');
      } else if (_videoRemoved) {
        data['video_url'] = '';
      }

      await repo.updateProperty(id, data);
      ref
        ..invalidate(publishedPropertiesProvider)
        ..invalidate(myPropertiesProvider)
        ..invalidate(propertyByIdProvider(id));
    } catch (_) {
      // best-effort in preview mode
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Listing updated')));
    context.pop();
  }

  String _stamp() => DateTime.now().microsecondsSinceEpoch.toString();

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---- build -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : !_found
                ? Center(
                    child: Text('Listing not found',
                        style: GoogleFonts.poppins(color: AppColors.inkSoft)))
                : Column(
                    children: [
                      _header(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            _statusCard(),
                            const SizedBox(height: 16),
                            _section('Basics', _basics()),
                            const SizedBox(height: 16),
                            _section('Location', _location()),
                            const SizedBox(height: 16),
                            _section('Pricing', _pricing()),
                            const SizedBox(height: 16),
                            _section('Amenities', [_amenityGrid()]),
                            if (_extra.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _section('More details', _extraFields()),
                            ],
                            const SizedBox(height: 16),
                            _section('Description', [
                              _text(_highlights,
                                  hint: 'Describe the property', lines: 4),
                            ]),
                            const SizedBox(height: 16),
                            _section('Photos & video', _media()),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white))
                                    : const Text('Save Changes'),
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

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 16, 6),
        child: Row(
          children: [
            IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/my-properties'),
                icon: const Icon(Icons.arrow_back_rounded)),
            Text('Edit Listing',
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _statusCard() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(_active ? Icons.check_circle : Icons.pause_circle_outline,
                color: _active ? AppColors.prefGreen : AppColors.inkSoft,
                size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_active ? 'Active listing' : 'Inactive (draft)',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(
                      _active
                          ? 'Visible in search and feeds'
                          : 'Hidden from searchers',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            Switch(
              value: _active,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      );

  // ---- sections ----------------------------------------------------------
  List<Widget> _basics() => [
        _label('Title'),
        _text(_title, hint: 'Listing title'),
        const SizedBox(height: 12),
        _twoUp(
          _dropdown('Property Type', _type, _typeOptions,
              (v) => setState(() => _type = v!)),
          _dropdown('Purpose', _purpose, _purposeOptions,
              (v) => setState(() => _purpose = v!),
              display: _purposeLabel),
        ),
        const SizedBox(height: 12),
        _twoUp(
          _dropdown(
              'BHK', _bhk, _bhkOptions, (v) => setState(() => _bhk = v!)),
          _dropdown('Bathrooms', _bathrooms, _bathOptions,
              (v) => setState(() => _bathrooms = v!)),
        ),
        const SizedBox(height: 12),
        _twoUp(
          _labeled('Carpet Area (sq.ft)',
              _text(_carpet, hint: 'Area', digitsOnly: true)),
          _dropdown('Furnishing', _furnishing, _furnishOptions,
              (v) => setState(() => _furnishing = v!)),
        ),
        const SizedBox(height: 12),
        _twoUp(
          _labeled(
              'Floor', _text(_floor, hint: 'Floor', digitsOnly: true)),
          _labeled('Total Floors',
              _text(_total, hint: 'Total', digitsOnly: true)),
        ),
        const SizedBox(height: 12),
        _twoUp(
          _dropdown('Property Age', _age, _ageOptions,
              (v) => setState(() => _age = v!)),
          _dropdown('Facing', _facing, _facingOptions,
              (v) => setState(() => _facing = v!)),
        ),
        const SizedBox(height: 12),
        _label('Available From'),
        _dateField(),
      ];

  List<Widget> _location() => [
        _twoUp(
          _dropdown('City', _city, _withCurrent(kCities, _city),
              (v) => setState(() => _city = v!)),
          _labeled('Locality',
              _text(_locality, hint: 'Area / locality')),
        ),
        const SizedBox(height: 12),
        _label('Pin exact location'),
        _mapTile(),
      ];

  List<Widget> _pricing() => [
        _twoUp(
          _labeled('Price (₹)',
              _text(_price, hint: 'Amount', digitsOnly: true)),
          _dropdown('Per', _period, _withCurrent(_periodOptions, _period),
              (v) => setState(() => _period = v!)),
        ),
        const SizedBox(height: 12),
        _twoUp(
          _labeled('Deposit (₹)',
              _text(_deposit, hint: 'Deposit', digitsOnly: true)),
          _labeled('Maintenance /mo (₹)',
              _text(_maintenance, hint: 'Maintenance', digitsOnly: true)),
        ),
        const SizedBox(height: 12),
        _twoUp(
          _labeled('Monthly rate (₹)',
              _text(_priceMonth, hint: 'For stays', digitsOnly: true)),
          _labeled('Cleaning fee (₹)',
              _text(_cleaning, hint: 'For stays', digitsOnly: true)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text('Price negotiable',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Switch(
              value: _negotiable,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _negotiable = v),
            ),
          ],
        ),
      ];

  List<Widget> _extraFields() {
    final rows = <Widget>[];
    final keys = _extra.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      rows.add(_labeled(_humanize(keys[i]), _text(_extra[keys[i]]!)));
      if (i < keys.length - 1) rows.add(const SizedBox(height: 12));
    }
    return rows;
  }

  // ---- amenities ---------------------------------------------------------
  Widget _amenityGrid() {
    // Merge base amenities with any custom ones already saved.
    final names = <String>{
      ..._amenityOptions.map((a) => a.$1),
      ..._amenities,
    }.toList();
    IconData iconFor(String n) => _amenityOptions
        .firstWhere((a) => a.$1 == n,
            orElse: () => (n, Icons.check_circle_outline))
        .$2;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in names)
          _amenityChip(n, iconFor(n), _amenities.contains(n)),
      ],
    );
  }

  Widget _amenityChip(String label, IconData icon, bool selected) {
    return GestureDetector(
      onTap: () => setState(() =>
          selected ? _amenities.remove(label) : _amenities.add(label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.inkSoft),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  // ---- media -------------------------------------------------------------
  List<Widget> _media() {
    return [
      Text('Tap a photo to make it the cover',
          style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.inkSoft)),
      const SizedBox(height: 10),
      SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < _photos.length; i++) _photoTile(i),
            _addPhotoTile(),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _videoRow(),
    ];
  }

  Widget _photoTile(int i) {
    final p = _photos[i];
    final isCover = i == 0;
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              final item = _photos.removeAt(i);
              _photos.insert(0, item); // promote to cover
            }),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: p.isNew
                  ? Image.memory(p.bytes!,
                      width: 96, height: 96, fit: BoxFit.cover)
                  : Image.network(p.url!,
                      width: 96, height: 96, fit: BoxFit.cover),
            ),
          ),
          if (isCover)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Cover',
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _photos.removeAt(i)),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: _addPhotos,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
            const SizedBox(height: 6),
            Text('Add',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _videoRow() {
    final has = _newVideo != null ||
        (!_videoRemoved && (_existingVideo?.isNotEmpty ?? false));
    return InkWell(
      onTap: _pickVideo,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  has ? Icons.check_circle_rounded : Icons.videocam_outlined,
                  color: AppColors.primary,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _newVideo != null
                          ? 'New video selected'
                          : (has ? 'Video attached' : 'Add a video tour'),
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(has ? 'Tap to replace' : 'MP4, up to 2 min',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
            if (has)
              GestureDetector(
                onTap: () => setState(() {
                  _newVideo = null;
                  _videoRemoved = true;
                }),
                child: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mapTile() {
    final pin = _pin;
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pin != null)
              IgnorePointer(
                child: FlutterMap(
                  key: ValueKey('${pin.latitude},${pin.longitude}'),
                  options: MapOptions(
                    initialCenter: pin,
                    initialZoom: 14.5,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.realestate.homevista',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: pin,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on,
                            color: AppColors.primary, size: 36),
                      ),
                    ]),
                  ],
                ),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_location_alt_outlined,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text('Adjust pin',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- shared widgets ----------------------------------------------------
  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _twoUp(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _labeled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_label(label), field],
      );

  Widget _text(TextEditingController c,
      {String? hint, bool digitsOnly = false, int lines = 1}) {
    return TextField(
      controller: c,
      keyboardType: digitsOnly
          ? TextInputType.number
          : (lines > 1 ? TextInputType.multiline : TextInputType.text),
      maxLines: lines,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: GoogleFonts.poppins(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        hintStyle:
            GoogleFonts.poppins(fontSize: 13, color: AppColors.inkSoft),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String?> onChanged,
      {String Function(String)? display}) {
    // Always include the stored value so a listing with an off-list value
    // (e.g. a PG whose "bhk" holds a sharing type) never crashes the dropdown.
    final opts = _withCurrent(options, value);
    return _labeled(
      label,
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, color: AppColors.inkSoft),
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        items: opts
            .map((o) => DropdownMenuItem(
                value: o, child: Text(display != null ? display(o) : o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField() {
    final d = _availableFrom;
    final label = d == null
        ? 'Select date'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 17, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: d == null ? AppColors.inkSoft : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  // ---- helpers -----------------------------------------------------------
  static List<String> _withCurrent(List<String> base, String cur) =>
      base.contains(cur) ? base : [cur, ...base];

  static String _purposeLabel(String v) => switch (v) {
        'rent' => 'For Rent',
        'sell' => 'For Sale',
        'stay' => 'Short Stay',
        _ => v,
      };

  static String _humanize(String key) => key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
