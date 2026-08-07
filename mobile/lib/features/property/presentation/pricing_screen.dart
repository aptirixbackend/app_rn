import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import 'widgets/posting_widgets.dart';

/// Posting step 3 — pricing. The fields adapt to what's being listed:
/// sale price, monthly rent + deposit, per-bed PG rent, or per-night +
/// per-month for a Stay.
class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen(
      {super.key, this.propertyId, this.type, this.purpose});

  final String? propertyId;
  final String? type; // canonical property_type
  final String? purpose; // canonical purpose ('sell'|'rent'|'stay')

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  final _price = TextEditingController();
  final _priceMonth = TextEditingController();
  final _deposit = TextEditingController();
  final _maintenance = TextEditingController();
  final _token = TextEditingController();
  final _cleaning = TextEditingController();
  bool _negotiable = true;

  String _type = 'Apartment';
  String _purpose = 'rent';
  Map<String, dynamic> _attrs = {};
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.type ?? 'Apartment';
    _purpose = widget.purpose ?? 'rent';
    if (widget.propertyId != null) {
      _load();
    } else {
      _ready = true;
    }
  }

  Future<void> _load() async {
    try {
      final row = await ref
          .read(propertyRepositoryProvider)
          .getPropertyById(widget.propertyId!);
      if (row != null) {
        _type = (row['property_type'] ?? _type).toString();
        _purpose = (row['purpose'] ?? _purpose).toString();
        if (row['attributes'] is Map) {
          _attrs = Map<String, dynamic>.from(row['attributes'] as Map);
        }
        final p = row['price'];
        if (p is num) _price.text = p.toString();
        _priceMonth.text = (_attrs['price_month'] ?? '').toString();
        _deposit.text = (_attrs['deposit'] ?? '').toString();
        _maintenance.text = (_attrs['maintenance'] ?? '').toString();
        _token.text = (_attrs['token_amount'] ?? '').toString();
        _cleaning.text = (_attrs['cleaning_fee'] ?? '').toString();
        if (_attrs['negotiable'] is bool) _negotiable = _attrs['negotiable'];
      }
    } catch (_) {
      // preview mode — keep defaults
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _price.dispose();
    _priceMonth.dispose();
    _deposit.dispose();
    _maintenance.dispose();
    _token.dispose();
    _cleaning.dispose();
    super.dispose();
  }

  String get _mode {
    if (_purpose == 'stay') return 'stay';
    if (_purpose == 'sell') return 'sale';
    if (_type == 'PG' || _type.toLowerCase() == 'coliving') return 'pg';
    return 'rent';
  }

  Future<void> _continue() async {
    if (_price.text.trim().isEmpty) {
      _snack('Please enter a price.');
      return;
    }
    setState(() => _saving = true);
    final period =
        _mode == 'stay' ? 'night' : (_mode == 'sale' ? 'total' : 'month');
    final attrs = {..._attrs};
    switch (_mode) {
      case 'sale':
        attrs['negotiable'] = _negotiable;
        if (_token.text.trim().isNotEmpty) {
          attrs['token_amount'] = _token.text.trim();
        }
      case 'rent':
        attrs['deposit'] = _deposit.text.trim();
        attrs['maintenance'] = _maintenance.text.trim();
        attrs['negotiable'] = _negotiable;
      case 'pg':
        attrs['deposit'] = _deposit.text.trim();
      case 'stay':
        attrs['price_month'] = _priceMonth.text.trim();
        attrs['cleaning_fee'] = _cleaning.text.trim();
    }
    try {
      if (widget.propertyId != null) {
        await ref.read(propertyRepositoryProvider).updateProperty(
          widget.propertyId!,
          {
            'price': num.tryParse(_price.text.trim()),
            'price_period': period,
            'attributes': attrs,
          },
        );
      }
    } catch (_) {
      // preview mode — continue
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.go('/post-property/amenities', extra: widget.propertyId);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  PostingProgressBar(
                    step: 3,
                    onBack: () => context.go('/post-property'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set your price',
                              style: GoogleFonts.poppins(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(_subtitle(),
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: AppColors.inkSoft)),
                          const SizedBox(height: 18),
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

  String _subtitle() {
    switch (_mode) {
      case 'sale':
        return 'Enter the expected sale price for this property.';
      case 'stay':
        return 'Set nightly and monthly rates for your stay.';
      case 'pg':
        return 'Set the rent per bed and the security deposit.';
      default:
        return 'Set the monthly rent, deposit and maintenance.';
    }
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
        children: _fields(),
      ),
    );
  }

  List<Widget> _fields() {
    switch (_mode) {
      case 'sale':
        return [
          _field('Expected Price', _price, suffix: '₹', big: true),
          _field('Booking / Token Amount (optional)', _token, suffix: '₹'),
          _negotiableTile(),
        ];
      case 'stay':
        return [
          _field('Price per Night', _price, suffix: '₹', big: true),
          _field('Price per Month', _priceMonth, suffix: '₹'),
          _field('Cleaning Fee (optional)', _cleaning, suffix: '₹'),
        ];
      case 'pg':
        return [
          _field('Rent per Bed (monthly)', _price, suffix: '₹', big: true),
          _field('Security Deposit', _deposit, suffix: '₹'),
        ];
      default: // rent
        return [
          _field('Monthly Rent', _price, suffix: '₹', big: true),
          _field('Security Deposit', _deposit, suffix: '₹'),
          _field('Maintenance / month (optional)', _maintenance, suffix: '₹'),
          _negotiableTile(),
        ];
    }
  }

  Widget _field(String label, TextEditingController c,
      {String? suffix, bool big = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.poppins(
                fontSize: big ? 20 : 15,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.currency_rupee_rounded,
                  color: AppColors.inkSoft, size: 20),
              hintText: '0',
              hintStyle: GoogleFonts.poppins(color: AppColors.inkSoft),
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
          ),
        ],
      ),
    );
  }

  Widget _negotiableTile() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Price Negotiable',
                  style: GoogleFonts.poppins(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text('Let buyers know the price is open to discussion',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
        ),
        Switch(
          value: _negotiable,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _negotiable = v),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _saving ? null : _continue,
            child: _saving
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
          const SecureNote(text: 'You can change your price anytime later'),
        ],
      ),
    );
  }
}
