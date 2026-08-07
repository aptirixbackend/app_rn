import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/theme/app_colors.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = ref.read(mockAuthProvider);
    _name.text = (await a.name()) ?? '';
    _email.text = (await a.email()) ?? '';
    _phone.text = ((await a.phone()) ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (_phone.text.length > 10) {
      _phone.text = _phone.text.substring(_phone.text.length - 10);
    }
    _city.text = (await a.city()) ?? '';
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Please enter your name.');
      return;
    }
    setState(() => _saving = true);
    await ref.read(mockAuthProvider).setProfile(
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : '+91${_phone.text.trim()}',
          city: _city.text.trim(),
        );
    ref.invalidate(userNameProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Profile updated');
    context.pop();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isNotEmpty ? _name.text.trim()[0] : 'U';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _header(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.14),
                                child: Text(initial,
                                    style: GoogleFonts.poppins(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFFF6F7FB),
                                          width: 3)),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      size: 15, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _field('Full Name', _name, Icons.person_outline_rounded,
                            hint: 'Your name'),
                        _field('Email', _email, Icons.mail_outline_rounded,
                            hint: 'you@email.com',
                            keyboard: TextInputType.emailAddress),
                        _field('Phone', _phone, Icons.phone_outlined,
                            hint: '10-digit mobile',
                            keyboard: TextInputType.phone,
                            digitsOnly: true,
                            maxLength: 10,
                            prefix: '+91 '),
                        _field('City', _city, Icons.location_on_outlined,
                            hint: 'City, State'),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4, color: Colors.white))
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
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
                icon: const Icon(Icons.arrow_back_rounded)),
            Text('Edit Profile',
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _field(String label, TextEditingController c, IconData icon,
      {String? hint,
      TextInputType? keyboard,
      bool digitsOnly = false,
      int? maxLength,
      String? prefix}) {
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
            keyboardType: keyboard,
            maxLength: maxLength,
            inputFormatters:
                digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13.5, color: AppColors.inkSoft),
              prefixIcon: Icon(icon, color: AppColors.inkSoft, size: 20),
              prefixText: prefix,
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
}
