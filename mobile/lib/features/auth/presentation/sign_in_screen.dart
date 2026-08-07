import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/auth_config.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/mock_auth.dart';
import '../../../core/theme/app_colors.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _fillDemo(String digits) {
    _phoneController.text = digits;
    _phoneController.selection =
        TextSelection.collapsed(offset: digits.length);
  }

  Future<void> _continueWithMobile() async {
    final digits = _phoneController.text.trim();
    if (digits.length != 10) {
      _snack('Please enter a valid 10-digit mobile number.');
      return;
    }
    final phone = '+91$digits';
    if (useRealAuth) {
      // Ask Supabase to send the code (delivered by the Plivo hook).
      setState(() => _loading = true);
      try {
        await ref.read(authServiceProvider).sendPhoneOtp(phone);
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        _snack('Could not send the code. Please try again.');
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) context.push('/verify-otp', extra: phone);
  }

  Future<void> _continueWithGoogle() async {
    if (useRealAuth) {
      setState(() => _loading = true);
      try {
        // OAuth redirect; the router's auth listener routes on completion.
        await ref.read(authServiceProvider).signInWithGoogle();
      } catch (_) {
        _snack('Google sign-in failed. Please try again.');
      }
      if (mounted) setState(() => _loading = false);
      return;
    }
    // Mock fallback (demo mode).
    setState(() => _loading = true);
    final auth = ref.read(mockAuthProvider);
    await auth.login('google');
    final onboarded = await auth.isOnboarded();
    if (mounted) {
      setState(() => _loading = false);
      context.go(onboarded ? '/home' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _hero(context),
              Transform.translate(
                offset: const Offset(0, -26),
                child: _sheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Hero image + logo -------------------------------------------------
  Widget _hero(BuildContext context) {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/home_signup.png', fit: BoxFit.cover),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: _logo(),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'H',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOMELY',
              style: GoogleFonts.poppins(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Find your perfect space',
              style: GoogleFonts.poppins(
                color: AppColors.inkSoft,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Bottom sheet ------------------------------------------------------
  Widget _sheet(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.boxBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: AppColors.ink,
                    ),
                    children: const [
                      TextSpan(text: 'Find Your\n'),
                      TextSpan(
                        text: 'Perfect Property',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Buy, rent or sell properties across\nthousands of verified listings.',
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    height: 1.4,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                _phoneField(),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _continueWithMobile,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue with Mobile'),
                ),
                const SizedBox(height: 14),
                _demoCard(),
                const SizedBox(height: 18),
                _orDivider(),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: _loading ? null : _continueWithGoogle,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/icons/google.svg',
                          width: 22, height: 22),
                      const SizedBox(width: 12),
                      const Text('Continue with Google'),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _trustRow(),
                const SizedBox(height: 18),
              ],
            ),
          ),
          Image.asset(
            'assets/images/bottom_design.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ],
      ),
    );
  }

  Widget _phoneField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇮🇳', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text('+91',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.ink)),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.inkSoft, size: 20),
              ],
            ),
          ),
          Container(width: 1, height: 26, color: AppColors.border),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Enter mobile number',
                hintStyle: GoogleFonts.poppins(color: AppColors.inkSoft),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoCard() {
    Widget account(
        String label, String digits, IconData icon, Color color) {
      final pretty = '${digits.substring(0, 5)} ${digits.substring(5)}';
      return Expanded(
        child: GestureDetector(
          onTap: () => _fillDemo(digits),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      Text(pretty,
                          style: GoogleFonts.poppins(
                              fontSize: 10.5, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Demo logins — tap to fill · OTP 123456',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              account('Property Owner', '9000000001',
                  Icons.storefront_outlined, AppColors.prefOrange),
              const SizedBox(width: 10),
              account('Home Buyer', '9000000002', Icons.person_outline_rounded,
                  AppColors.prefGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
                color: AppColors.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _trustRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _TrustBadge(
          icon: Icons.verified_user_rounded,
          title: 'Verified Listings',
          subtitle: '100% verified\nproperties',
        ),
        _TrustBadge(
          icon: Icons.home_rounded,
          title: 'Best Prices',
          subtitle: 'Find the best\ndeals',
        ),
        _TrustBadge(
          icon: Icons.forum_rounded,
          title: '24/7 Support',
          subtitle: "We're here to\nhelp you",
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              height: 1.3,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
