import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

const _steps = <(IconData, String, String)>[
  (
    Icons.ios_share_rounded,
    'Share your code',
    'Send your referral code to friends looking to rent, buy or list.'
  ),
  (
    Icons.person_add_alt_1_rounded,
    'They sign up',
    'Your friend joins RentoRent and completes their first enquiry or listing.'
  ),
  (
    Icons.card_giftcard_rounded,
    'You both earn',
    'You each get ₹500 in rewards once their first activity is verified.'
  ),
];

class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  static const _code = 'HOME-NAVEEN500';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _hero(),
                  const SizedBox(height: 16),
                  _codeCard(context),
                  const SizedBox(height: 22),
                  Text('How it works',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _steps.length; i++)
                    _step(i + 1, _steps[i]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.prefGreenBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.prefGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Total earned so far',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: AppColors.ink)),
                        ),
                        Text('₹0',
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.prefGreen)),
                      ],
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
            Text('Refer & Earn',
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF5B4EE8), Color(0xFF8E7BF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            Text('Invite friends, earn ₹500 each',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text('For every friend who joins and gets started',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      );

  Widget _codeCard(BuildContext context) {
    void copy() {
      Clipboard.setData(const ClipboardData(text: _code));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Referral code copied')));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('Your referral code',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: copy,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_code,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.primary)),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                      const SnackBar(content: Text('Sharing — coming soon')));
              },
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share Invite'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int n, (IconData, String, String) s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(s.$1, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$n. ${s.$2}',
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(s.$3,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, height: 1.4, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
