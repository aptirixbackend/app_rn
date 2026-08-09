import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/auth_config.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/mock_auth.dart';
import '../../../core/auth/session_reset.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shake_widget.dart';
import 'widgets/otp_input_field.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phoneE164});

  /// Full E.164 number, e.g. +919876543210.
  final String phoneE164;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const _resendSeconds = 25;

  String _code = '';
  bool _loading = false;
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  // Wrong-OTP feedback: bump [_shake] to trigger the shake + clear the boxes.
  int _shake = 0;
  bool _otpError = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _prettyPhone {
    // +919876543210 -> +91 98765 43210
    final p = widget.phoneE164;
    if (p.startsWith('+91') && p.length == 13) {
      final rest = p.substring(3);
      return '+91 ${rest.substring(0, 5)} ${rest.substring(5)}';
    }
    return p;
  }

  void _flagWrongOtp(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _otpError = true;
      _shake++; // triggers the shake + clears the boxes
      _code = '';
    });
    _snack(message);
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      _flagWrongOtp('Please enter the 6-digit code.');
      return;
    }
    final auth = ref.read(mockAuthProvider);

    if (useRealAuth) {
      // Backend verifies the code and returns the session JWT.
      setState(() => _loading = true);
      final bool onboarded;
      try {
        onboarded = await ref
            .read(authServiceProvider)
            .verifyOtp(widget.phoneE164, _code);
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        _flagWrongOtp('Invalid or expired code. Please try again.');
        return;
      }
      invalidateUserData(ref);
      if (mounted) {
        setState(() => _loading = false);
        context.go(onboarded ? '/home' : '/onboarding');
      }
      return;
    }

    if (!auth.verifyOtp(_code)) {
      _flagWrongOtp('Invalid OTP. For testing, use 123456.');
      return;
    }
    setState(() => _loading = true);
    await auth.login(widget.phoneE164);
    await auth.applyDemoAccount(widget.phoneE164);
    final onboarded = await auth.isOnboarded();
    // Refresh role/name so Home + nav render in the correct role immediately.
    ref
      ..invalidate(userRoleProvider)
      ..invalidate(userNameProvider);
    if (mounted) {
      setState(() => _loading = false);
      context.go(onboarded ? '/home' : '/onboarding');
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    if (useRealAuth) {
      try {
        await ref.read(authServiceProvider).requestOtp(widget.phoneE164);
      } catch (_) {
        _snack('Could not resend the code. Please try again.');
        return;
      }
      _snack('Code re-sent on WhatsApp.');
      _startCountdown();
      return;
    }
    _snack('OTP resent. For testing, use 123456.');
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Image.asset(
                'assets/images/otp_screen.png',
                height: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Mobile',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit OTP sent to',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 2),
              Text(
                _prettyPhone,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              ShakeWidget(
                trigger: _shake,
                child: OtpInputField(
                  error: _otpError,
                  resetToken: _shake,
                  onChanged: (v) => setState(() {
                    _code = v;
                    if (_otpError) _otpError = false;
                  }),
                  onCompleted: (_) => _verify(),
                ),
              ),
              if (!useRealAuth) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Demo mode — enter OTP  123456',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary)),
                ),
              ],
              const SizedBox(height: 16),
              _resendRow(),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Verify & Continue'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resendRow() {
    final canResend = _secondsLeft == 0;
    final timerText = _secondsLeft == 0
        ? ''
        : ' (00:${_secondsLeft.toString().padLeft(2, '0')})';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive OTP? ",
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        GestureDetector(
          onTap: canResend ? _resend : null,
          child: Text(
            'Resend OTP$timerText',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: canResend ? AppColors.primary : AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}
