import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../data/onboarding_repository.dart';

class _Pref {
  const _Pref(this.value, this.title, this.subtitle, this.icon, this.accent,
      this.accentBg);
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentBg;
}

const _prefs = <_Pref>[
  _Pref('rent', 'Rent a Home', 'Find your perfect rental', Icons.home_rounded,
      AppColors.prefGreen, AppColors.prefGreenBg),
  _Pref('coliving', 'Co-living', 'Shared spaces, better living',
      Icons.groups_rounded, AppColors.prefPurple, AppColors.prefPurpleBg),
  _Pref('pg', 'PG / Hostel', 'Comfortable stays', Icons.single_bed_rounded,
      AppColors.prefOrange, AppColors.prefOrangeBg),
  _Pref('buy', 'Buy a Home', 'Find your dream home', Icons.apartment_rounded,
      AppColors.prefBlue, AppColors.prefBlueBg),
  _Pref('investment', 'Invest', 'Smart real estate investments',
      Icons.show_chart_rounded, AppColors.prefPink, AppColors.prefPinkBg),
];

class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _selected = <String>{};
  DateTime? _dob;
  bool _loading = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _continue() async {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      _snack('Please enter your first and last name.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(onboardingRepositoryProvider).saveAboutYou(
            firstName: _firstCtrl.text.trim(),
            lastName: _lastCtrl.text.trim(),
            dob: _dob,
            email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            preferences: _selected.toList(),
          );
    } catch (_) {
      // Preview mode — ignore and continue.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    final auth = ref.read(mockAuthProvider);
    await auth.setOnboarded(
        name: '${_firstCtrl.text.trim()} ${_lastCtrl.text.trim()}');
    await auth.setProfile(
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim());
    ref
      ..invalidate(userNameProvider)
      ..invalidate(userEmailProvider);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final cardW = (MediaQuery.of(context).size.width - 48 - 12) / 2;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell us about yourself',
                      style: GoogleFonts.poppins(
                          fontSize: 25, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This helps us personalize your\nexperience',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, height: 1.4, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _nameField(_firstCtrl, 'First Name')),
                        const SizedBox(width: 12),
                        Expanded(child: _nameField(_lastCtrl, 'Last Name')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _dobField(),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email Address',
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            color: AppColors.inkSoft, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'What are you looking for?',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can select more than one',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          _prefs.map((p) => _prefCard(p, cardW)).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: FilledButton(
                onPressed: _loading ? null : _continue,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(child: Center(child: _stepDots(active: 0))),
          TextButton(
            onPressed: () async {
              await ref.read(mockAuthProvider).setOnboarded();
              if (mounted) context.go('/home');
            },
            child: Text(
              'Skip',
              style: GoogleFonts.poppins(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDots({int count = 5, int active = 0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(width: 16, height: 2, color: AppColors.border);
        }
        final idx = i ~/ 2;
        final on = idx <= active;
        return Container(
          width: on ? 10 : 8,
          height: on ? 10 : 8,
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.border,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _nameField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.person_outline_rounded,
            color: AppColors.inkSoft, size: 20),
      ),
    );
  }

  Widget _dobField() {
    final has = _dob != null;
    final label = has
        ? '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
        : 'Date of Birth';
    return InkWell(
      onTap: _pickDob,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_today_outlined,
              color: AppColors.inkSoft, size: 18),
          suffixIcon: Icon(Icons.expand_more_rounded, color: AppColors.inkSoft),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: has ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  Widget _prefCard(_Pref p, double width) {
    final selected = _selected.contains(p.value);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(p.value);
        } else {
          _selected.add(p.value);
        }
      }),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(p.icon, color: p.accent, size: 20),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? p.accent : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? p.accent : AppColors.border,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              p.title,
              style: GoogleFonts.poppins(
                  fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              p.subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 11, height: 1.3, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
