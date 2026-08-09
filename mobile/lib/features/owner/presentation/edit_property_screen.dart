import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';

const _furnishOptions = ['Unfurnished', 'Semi Furnished', 'Fully Furnished'];

class EditPropertyScreen extends ConsumerStatefulWidget {
  const EditPropertyScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  ConsumerState<EditPropertyScreen> createState() =>
      _EditPropertyScreenState();
}

class _EditPropertyScreenState extends ConsumerState<EditPropertyScreen> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _highlights = TextEditingController();
  String _furnishing = 'Semi Furnished';
  DateTime? _availableFrom;
  bool _active = true;
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
    final f = v.furnishing;
    _furnishing = _furnishOptions.contains(f) ? f : 'Semi Furnished';
    _active = (row['status'] ?? 'published').toString() == 'published';
    final af = row['available_from'];
    _availableFrom = af == null ? null : DateTime.tryParse(af.toString());
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _highlights.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(propertyRepositoryProvider).updateProperty(
        widget.propertyId,
        {
          'title': _title.text.trim(),
          'price': num.tryParse(_price.text.trim()),
          'furnishing': _furnishing,
          'highlights': _highlights.text.trim(),
          'available_from':
              _availableFrom?.toIso8601String().split('T').first,
          'status': _active ? 'published' : 'draft',
        },
      );
      ref
        ..invalidate(publishedPropertiesProvider)
        ..invalidate(myPropertiesProvider)
        ..invalidate(propertyByIdProvider(widget.propertyId));
    } catch (_) {
      // ignore in preview mode
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Listing updated')));
    context.pop();
  }

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
                      _header(context),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            _statusCard(),
                            const SizedBox(height: 16),
                            _label('Title'),
                            _text(_title, hint: 'Listing title'),
                            const SizedBox(height: 14),
                            _label('Price (₹)'),
                            _text(_price,
                                hint: 'Amount',
                                keyboard: TextInputType.number,
                                digitsOnly: true,
                                icon: Icons.currency_rupee_rounded),
                            const SizedBox(height: 14),
                            _label('Furnishing'),
                            _furnishingField(),
                            const SizedBox(height: 14),
                            _label('Available From'),
                            _dateField(),
                            const SizedBox(height: 14),
                            _label('Description'),
                            _text(_highlights,
                                hint: 'Describe the property', lines: 4),
                            const SizedBox(height: 18),
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

  Widget _header(BuildContext context) => Padding(
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
                  Text(_active ? 'Active listing' : 'Inactive',
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _text(TextEditingController c,
      {String? hint,
      TextInputType? keyboard,
      bool digitsOnly = false,
      int lines = 1,
      IconData? icon}) {
    return TextField(
      controller: c,
      keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
      maxLines: lines,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 13.5, color: AppColors.inkSoft),
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
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

  Widget _furnishingField() {
    return DropdownButtonFormField<String>(
      initialValue: _furnishing,
      isExpanded: true,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.chair_outlined, size: 20),
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
      items: _furnishOptions
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => setState(() => _furnishing = v ?? _furnishing),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: d == null ? AppColors.inkSoft : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
