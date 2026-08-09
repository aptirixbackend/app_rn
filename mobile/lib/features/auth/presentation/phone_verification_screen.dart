import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/mock_auth.dart';
import '../../../core/auth/session_reset.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shake_widget.dart';
import 'widgets/otp_input_field.dart';

/// Shown right after a first-time Google sign-in: we have their name + email
/// from Google, but need a verified phone number before letting them into Home.
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _phoneCtrl = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String _code = '';
  int _shake = 0;
  bool _otpError = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 25);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _phoneE164 => '+91${_phoneCtrl.text.trim()}';

  Future<void> _sendCode() async {
    final digits = _phoneCtrl.text.trim();
    if (digits.length != 10) {
      _snack('Please enter a valid 10-digit mobile number.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).requestOtp(_phoneE164);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _loading = false;
      });
      _startCountdown();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _snack('Could not send the code. Please try again.');
    }
  }

  void _flagWrong(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _otpError = true;
      _shake++;
      _code = '';
    });
    _snack(message);
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      _flagWrong('Please enter the 6-digit code.');
      return;
    }
    setState(() => _loading = true);
    final bool onboarded;
    try {
      onboarded =
          await ref.read(authServiceProvider).attachPhone(_phoneE164, _code);
    } on DioException catch (e) {
      if (mounted) setState(() => _loading = false);
      _flagWrong(e.response?.statusCode == 409
          ? 'This number is already registered — sign in with it instead.'
          : 'Invalid or expired code. Please try again.');
      return;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _flagWrong('Invalid or expired code. Please try again.');
      return;
    }
    invalidateUserData(ref);
    if (mounted) {
      setState(() => _loading = false);
      context.go(onboarded ? '/home' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(userNameProvider).asData?.value;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/sign-in'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16)),
                child:
                    const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(
                  name == null || name.isEmpty
                      ? 'Verify your mobile number'
                      : 'Almost there, $name',
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'We got your details from Google. Add and verify your mobile '
                'number to finish setting up your account.',
                style: GoogleFonts.poppins(
                    fontSize: 13.5, height: 1.4, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              _phoneField(),
              const SizedBox(height: 16),
              if (!_sent)
                FilledButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('Send Code'),
                )
              else ...[
                Text('Enter the 6-digit code sent on WhatsApp',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.inkSoft)),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                _resendRow(),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('Verify & Continue'),
                ),
              ],
            ],
          ),
        ),
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
            child: Text('🇮🇳 +91',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
          Container(width: 1, height: 26, color: AppColors.border),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              enabled: !_sent,
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
          if (_sent)
            TextButton(
              onPressed: () => setState(() {
                _sent = false;
                _code = '';
              }),
              child: Text('Change',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  Widget _resendRow() {
    final canResend = _secondsLeft == 0;
    return Row(
      children: [
        Text("Didn't get it? ",
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.inkSoft)),
        GestureDetector(
          onTap: canResend ? _sendCode : null,
          child: Text(
            canResend
                ? 'Resend code'
                : 'Resend in 00:${_secondsLeft.toString().padLeft(2, '0')}',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: canResend ? AppColors.primary : AppColors.inkSoft),
          ),
        ),
      ],
    );
  }
}
