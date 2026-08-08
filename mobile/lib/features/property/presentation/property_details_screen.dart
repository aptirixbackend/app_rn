import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/city_store.dart';
import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import 'location_picker_screen.dart';
import 'widgets/posting_widgets.dart';

const _types = <(String, IconData)>[
  ('Apartment', Icons.apartment_rounded),
  ('Villa', Icons.villa_rounded),
  ('Independent House', Icons.house_rounded),
  ('Plot / Land', Icons.terrain_rounded),
  ('Commercial', Icons.business_center_rounded),
];

const _purposes = <(String, IconData)>[
  ('Sell', Icons.sell_outlined),
  ('Rent', Icons.vpn_key_outlined),
  ('PG / Co-living', Icons.groups_outlined),
  ('Stay', Icons.night_shelter_outlined),
  ('Lease', Icons.description_outlined),
];

const _bhkOptions = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK', '5+ BHK'];
const _bathOptions = ['1', '2', '3', '4', '5+'];
const _furnishOptions = ['Unfurnished', 'Semi Furnished', 'Fully Furnished'];
const _ageOptions = [
  'Under Construction',
  'New',
  '0-1 years',
  '1-5 years',
  '5-10 years',
  '10+ years'
];
const _facingOptions = [
  'East',
  'West',
  'North',
  'South',
  'North-East',
  'North-West',
  'South-East',
  'South-West'
];
// PG / Co-living
const _sharingOptions = [
  'Single Sharing',
  'Double Sharing',
  'Triple Sharing',
  'Four Sharing',
  'Private Room'
];
const _foodOptions = ['With Food', 'Without Food', 'Food Optional'];
const _genderOptions = ['Men', 'Women', 'Co-ed'];
const _gateOptions = ['9:00 PM', '10:00 PM', '11:00 PM', 'No Restriction'];
const _noticeOptions = ['15 Days', '1 Month', '2 Months'];
// Plot / Land
const _boundaryOptions = ['Yes', 'No'];
const _approvalOptions = [
  'DTCP Approved',
  'BBMP Approved',
  'Gram Panchayat',
  'Unapproved'
];
// Commercial
const _lockInOptions = ['None', '6 Months', '1 Year', '2 Years', '3 Years'];
// Stay
const _stayTypeOptions = [
  'Entire House',
  'Private Room',
  'Shared Room',
  'Studio'
];
const _maxGuestOptions = ['1', '2', '3', '4', '5', '6+'];
const _minNightsOptions = ['1', '2', '3', '7', '30'];
const _checkTimeOptions = [
  '11:00 AM',
  '12:00 PM',
  '1:00 PM',
  '2:00 PM',
  '3:00 PM'
];

class PropertyDetailsScreen extends ConsumerStatefulWidget {
  const PropertyDetailsScreen({super.key});

  @override
  ConsumerState<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends ConsumerState<PropertyDetailsScreen> {
  // Pre-filled to match the design mockup.
  String _type = 'Apartment';
  String _purpose = 'Rent';
  String _bhk = '2 BHK';
  String _bathrooms = '2';
  String _furnishing = 'Semi Furnished';
  String _age = '5-10 years';
  String _facing = 'East';
  // PG / Co-living
  String _sharing = 'Double Sharing';
  String _food = 'With Food';
  String _gender = 'Men';
  String _gate = '11:00 PM';
  String _notice = '1 Month';
  // Plot / Land
  String _boundary = 'Yes';
  String _approval = 'DTCP Approved';
  // Commercial
  String _lockIn = '1 Year';
  // Stay
  String _stayType = 'Entire House';
  String _maxGuests = '2';
  String _minNights = '1';
  String _checkIn = '2:00 PM';
  String _checkOut = '11:00 AM';
  DateTime? _availableFrom;
  bool _loading = false;

  String _city = kCities.first;
  LatLng? _pin; // exact pinned location on the map
  final _localityCtrl = TextEditingController();

  LatLng _cityCenterLL(String c) {
    final (lat, lng) = cityCenter(c);
    return LatLng(lat, lng);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initial: _pin ?? _cityCenterLL(_city)),
      ),
    );
    if (result != null && mounted) setState(() => _pin = result);
  }

  final _carpetCtrl = TextEditingController(text: '950');
  final _floorCtrl = TextEditingController(text: '5');
  final _totalCtrl = TextEditingController(text: '12');
  final _lenCtrl = TextEditingController(text: '30');
  final _widthCtrl = TextEditingController(text: '40');
  final _seatsCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _city = ref.read(selectedCityProvider);
    _pin = _cityCenterLL(_city);
  }

  /// Which type-specific field set to show/collect.
  String get _mode {
    if (_purpose == 'PG / Co-living') return 'pg';
    if (_purpose == 'Stay') return 'stay';
    if (_type == 'Plot / Land') return 'plot';
    if (_type == 'Commercial') return 'commercial';
    return 'residential';
  }

  /// Canonical property_type stored in the DB (matches the filter/segment set).
  String _canonicalType() {
    if (_purpose == 'PG / Co-living') return 'PG';
    if (_purpose == 'Stay') return 'Stay';
    if (_type == 'Plot / Land') return 'Plot';
    return _type; // Apartment / Villa / Independent House / Commercial
  }

  /// Canonical purpose stored in the DB ('rent' | 'sell' | 'stay').
  String _canonicalPurpose() {
    if (_purpose == 'PG / Co-living') return 'rent';
    if (_purpose == 'Stay') return 'stay';
    return _purpose == 'Sell' ? 'sell' : 'rent'; // Rent / Lease -> rent
  }

  Map<String, dynamic> _attributes() {
    switch (_mode) {
      case 'pg':
        return {
          'sharing': _sharing,
          'food': _food,
          'gender': _gender,
          'gate_timing': _gate,
          'notice_period': _notice,
        };
      case 'plot':
        return {
          'plot_length': _lenCtrl.text,
          'plot_width': _widthCtrl.text,
          'boundary': _boundary,
          'approval': _approval,
        };
      case 'commercial':
        return {'seats': _seatsCtrl.text, 'lock_in': _lockIn};
      case 'stay':
        return {
          'stay_type': _stayType,
          'max_guests': _maxGuests,
          'min_nights': _minNights,
          'check_in': _checkIn,
          'check_out': _checkOut,
        };
      default:
        return {};
    }
  }

  @override
  void dispose() {
    _localityCtrl.dispose();
    _carpetCtrl.dispose();
    _floorCtrl.dispose();
    _totalCtrl.dispose();
    _lenCtrl.dispose();
    _widthCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  /// Floors only apply to apartments and commercial spaces.
  bool _hasFloor() =>
      _mode == 'commercial' || (_mode == 'residential' && _type == 'Apartment');

  Future<String?> _createDraft() {
    final mode = _mode;
    final residentialOrCommercial =
        mode == 'residential' || mode == 'commercial';
    return ref.read(propertyRepositoryProvider).createDraftBasics(
          propertyType: _canonicalType(),
          purpose: _canonicalPurpose(),
          city: _city,
          latitude: _pin?.latitude,
          longitude: _pin?.longitude,
          area: _localityCtrl.text.trim().isEmpty
              ? null
              : _localityCtrl.text.trim(),
          bhk: mode == 'residential' || mode == 'stay'
              ? _bhk
              : (mode == 'pg' ? _sharing : null),
          bathrooms: residentialOrCommercial
              ? int.tryParse(_bathrooms.replaceAll(RegExp(r'[^0-9]'), ''))
              : null,
          carpetArea: num.tryParse(_carpetCtrl.text),
          furnishing: mode == 'plot'
              ? null
              : (mode == 'pg' || mode == 'stay'
                  ? 'Fully Furnished'
                  : _furnishing),
          floorNumber: _hasFloor() ? int.tryParse(_floorCtrl.text) : null,
          totalFloors: _hasFloor() ? int.tryParse(_totalCtrl.text) : null,
          propertyAge: residentialOrCommercial ? _age : null,
          facing: mode == 'pg' || mode == 'stay' ? null : _facing,
          availableFrom: _availableFrom,
          attributes: _attributes(),
        );
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    String? id;
    try {
      id = await _createDraft();
    } catch (_) {
      // Preview mode — ignore and continue.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) {
      context.go('/post-property/pricing', extra: {
        'id': id,
        'type': _canonicalType(),
        'purpose': _canonicalPurpose(),
      });
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _loading = true);
    try {
      await _createDraft();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    ref.invalidate(myPropertiesProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('Saved to drafts — resume from My Properties')));
    context.go('/my-properties');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            PostingProgressBar(
              step: 2,
              onBack: () => context.go('/home'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    _formCard(),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tell us about\nyour property',
                  style: GoogleFonts.poppins(
                      fontSize: 23, height: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Provide the basic details of\nyour property',
                  style: GoogleFonts.poppins(
                      fontSize: 13, height: 1.35, color: AppColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Image.asset('assets/images/tellus_properity.png',
            width: 104, fit: BoxFit.contain),
      ],
    );
  }

  Widget _formCard() {
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
          _sectionLabel('Property Type'),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              itemBuilder: (_, i) => _typeChip(_types[i].$1, _types[i].$2),
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('Purpose'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _purposes.map((p) => _purposeChip(p.$1, p.$2)).toList(),
          ),
          const SizedBox(height: 18),
          _sectionLabel('Location'),
          const SizedBox(height: 10),
          _twoUp(
            _dropdown('City', _city, kCities, Icons.location_city_outlined,
                (v) => setState(() {
                      _city = v!;
                      _pin = _cityCenterLL(_city); // re-centre the pin
                    })),
            _labeled(
              'Locality',
              TextField(
                controller: _localityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: AppColors.inkSoft, size: 20),
                  hintText: 'Area / locality',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _labeled('Pin exact location', _mapPickTile()),
          const SizedBox(height: 18),
          ..._typeSpecificFields(),
        ],
      ),
    );
  }

  // ---- type-specific field sets -----------------------------------------
  List<Widget> _typeSpecificFields() {
    switch (_mode) {
      case 'pg':
        return _pgFields();
      case 'stay':
        return _stayFields();
      case 'plot':
        return _plotFields();
      case 'commercial':
        return _commercialFields();
      default:
        return _residentialFields();
    }
  }

  List<Widget> _stayFields() => [
        _twoUp(
          _dropdown('Stay Type', _stayType, _stayTypeOptions,
              Icons.hotel_outlined, (v) => setState(() => _stayType = v!)),
          _dropdown('Max Guests', _maxGuests, _maxGuestOptions,
              Icons.people_alt_outlined,
              (v) => setState(() => _maxGuests = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _dropdown('Bedrooms', _bhk, _bhkOptions, Icons.bed_outlined,
              (v) => setState(() => _bhk = v!)),
          _dropdown('Min Nights', _minNights, _minNightsOptions,
              Icons.nights_stay_outlined,
              (v) => setState(() => _minNights = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _dropdown('Check-in', _checkIn, _checkTimeOptions,
              Icons.login_rounded, (v) => setState(() => _checkIn = v!)),
          _dropdown('Check-out', _checkOut, _checkTimeOptions,
              Icons.logout_rounded, (v) => setState(() => _checkOut = v!)),
        ),
        const SizedBox(height: 14),
        _labeled('Available From', _dateField()),
      ];

  Widget _twoUp(Widget a, Widget b) => Row(children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ]);

  Widget _suffixField(TextEditingController c, IconData icon, String suffix) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.inkSoft, size: 20),
          suffixText: suffix,
        ),
      );

  List<Widget> _residentialFields() => [
        _twoUp(
          _dropdown('BHK', _bhk, _bhkOptions, Icons.bed_outlined,
              (v) => setState(() => _bhk = v!)),
          _dropdown('Bathrooms', _bathrooms, _bathOptions,
              Icons.bathtub_outlined, (v) => setState(() => _bathrooms = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _labeled('Carpet Area',
              _suffixField(_carpetCtrl, Icons.square_foot_rounded, 'sq.ft')),
          _dropdown('Furnishing', _furnishing, _furnishOptions,
              Icons.chair_outlined, (v) => setState(() => _furnishing = v!)),
        ),
        const SizedBox(height: 14),
        // Floors only make sense for apartments — a villa / independent house
        // is standalone, so hide them there.
        if (_type == 'Apartment') ...[
          _twoUp(
            _labeled('Floor Number',
                _numberField(_floorCtrl, Icons.stairs_outlined)),
            _labeled('Total Floors',
                _numberField(_totalCtrl, Icons.layers_outlined)),
          ),
          const SizedBox(height: 14),
        ],
        _twoUp(
          _dropdown('Property Age', _age, _ageOptions, Icons.event_outlined,
              (v) => setState(() => _age = v!)),
          _dropdown('Facing', _facing, _facingOptions, Icons.explore_outlined,
              (v) => setState(() => _facing = v!)),
        ),
        const SizedBox(height: 14),
        _labeled('Available From', _dateField()),
      ];

  List<Widget> _pgFields() => [
        _twoUp(
          _dropdown('Occupancy / Sharing', _sharing, _sharingOptions,
              Icons.groups_outlined, (v) => setState(() => _sharing = v!)),
          _dropdown('Food', _food, _foodOptions, Icons.restaurant_rounded,
              (v) => setState(() => _food = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _dropdown('Preferred For', _gender, _genderOptions,
              Icons.people_alt_outlined, (v) => setState(() => _gender = v!)),
          _dropdown('Gate Timing', _gate, _gateOptions,
              Icons.access_time_rounded, (v) => setState(() => _gate = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _labeled('Room Size',
              _suffixField(_carpetCtrl, Icons.square_foot_rounded, 'sq.ft')),
          _dropdown('Notice Period', _notice, _noticeOptions,
              Icons.event_note_outlined, (v) => setState(() => _notice = v!)),
        ),
        const SizedBox(height: 14),
        _labeled('Available From', _dateField()),
      ];

  List<Widget> _plotFields() => [
        _twoUp(
          _labeled('Plot Area',
              _suffixField(_carpetCtrl, Icons.square_foot_rounded, 'sq.ft')),
          _dropdown('Facing', _facing, _facingOptions, Icons.explore_outlined,
              (v) => setState(() => _facing = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _labeled('Length', _suffixField(_lenCtrl, Icons.straighten_rounded, 'ft')),
          _labeled('Width', _suffixField(_widthCtrl, Icons.straighten_rounded, 'ft')),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _dropdown('Boundary Wall', _boundary, _boundaryOptions,
              Icons.fence_outlined, (v) => setState(() => _boundary = v!)),
          _dropdown('Approval', _approval, _approvalOptions,
              Icons.verified_outlined, (v) => setState(() => _approval = v!)),
        ),
        const SizedBox(height: 14),
        _labeled('Available From', _dateField()),
      ];

  List<Widget> _commercialFields() => [
        _twoUp(
          _labeled('Carpet Area',
              _suffixField(_carpetCtrl, Icons.square_foot_rounded, 'sq.ft')),
          _dropdown('Washrooms', _bathrooms, _bathOptions,
              Icons.wc_outlined, (v) => setState(() => _bathrooms = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _labeled('Seats / Workstations',
              _suffixField(_seatsCtrl, Icons.event_seat_outlined, 'seats')),
          _dropdown('Furnishing', _furnishing, _furnishOptions,
              Icons.chair_outlined, (v) => setState(() => _furnishing = v!)),
        ),
        const SizedBox(height: 14),
        _twoUp(
          _labeled('Floor', _numberField(_floorCtrl, Icons.stairs_outlined)),
          _dropdown('Lock-in Period', _lockIn, _lockInOptions,
              Icons.lock_clock_outlined, (v) => setState(() => _lockIn = v!)),
        ),
        const SizedBox(height: 14),
        _labeled('Available From', _dateField()),
      ];

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
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _loading ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text('Save as Draft',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined,
                  size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Text('All information is secure and private',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- small helpers -----------------------------------------------------
  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600));

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink)),
      );

  Widget _labeled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_fieldLabel(label), field],
      );

  Widget _typeChip(String label, IconData icon) {
    final selected = _type == label;
    return GestureDetector(
      onTap: () => setState(() => _type = label),
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purposeChip(String label, IconData icon) {
    final selected = _purpose == label;
    return GestureDetector(
      onTap: () => setState(() => _purpose = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      IconData icon, ValueChanged<String?> onChanged) {
    return _labeled(
      label,
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, color: AppColors.inkSoft),
        style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.ink),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.inkSoft, size: 18),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField(TextEditingController c, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.inkSoft, size: 18),
      ),
    );
  }

  Widget _dateField() {
    final has = _availableFrom != null;
    final d = _availableFrom;
    final label = has
        ? '${d!.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
        : 'Select date';
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_today_outlined,
              color: AppColors.inkSoft, size: 18),
          suffixIcon:
              Icon(Icons.expand_more_rounded, color: AppColors.inkSoft),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: has ? AppColors.ink : AppColors.inkSoft)),
      ),
    );
  }

  Widget _mapPickTile() {
    final pin = _pin;
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        height: 150,
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
                  // Rebuild the preview whenever the pin moves.
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
}
