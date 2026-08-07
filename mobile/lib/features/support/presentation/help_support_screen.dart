import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

const _faqs = <(String, String)>[
  (
    'How do I schedule a site visit?',
    'Open any property, tap "Schedule Visit", pick a date and confirm. '
        'The owner is notified and you can track it under Site Visits.'
  ),
  (
    'How do I contact a property owner?',
    'On the property detail page use Contact, WhatsApp or Message. Your '
        'enquiry is saved and the owner receives it as a lead.'
  ),
  (
    'How do I list my property?',
    'Tap the + button in the bottom bar, choose your property type and '
        'purpose, fill in the details, add photos and publish.'
  ),
  (
    'Are the listings verified?',
    'Listings marked "Verified" have been checked by our team. Always visit '
        'in person before making any payment.'
  ),
  (
    'How do I edit or remove my listing?',
    'Go to Profile → My Properties, open a listing and tap Edit to update it '
        'or change its status.'
  ),
];

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  void _snack(BuildContext context, String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

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
                  const SizedBox(height: 18),
                  Text('Contact us',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _contact(context, Icons.call_rounded, 'Call',
                          'Call us at +91 80 4718 2000', AppColors.prefGreen,
                          AppColors.prefGreenBg),
                      const SizedBox(width: 10),
                      _contact(context, Icons.forum_outlined, 'WhatsApp',
                          'WhatsApp us at +91 90000 12345', AppColors.primary,
                          AppColors.primarySoft),
                      const SizedBox(width: 10),
                      _contact(context, Icons.mail_outline_rounded, 'Email',
                          'Email support@homevista.app', AppColors.prefOrange,
                          AppColors.prefOrangeBg),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Frequently asked',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < _faqs.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: AppColors.border),
                          _FaqTile(q: _faqs[i].$1, a: _faqs[i].$2),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _snack(
                          context, 'Email us at support@homevista.app'),
                      icon: const Icon(Icons.support_agent_rounded, size: 20),
                      label: const Text('Contact Support Team'),
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
            Text('Help & Support',
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF5B4EE8), Color(0xFF8E7BF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How can we help?',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("We're here for you 24/7",
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle),
              child: const Icon(Icons.headset_mic_rounded,
                  color: Colors.white, size: 26),
            ),
          ],
        ),
      );

  Widget _contact(BuildContext context, IconData icon, String label,
      String detail, Color color, Color bg) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _snack(context, detail),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.q, required this.a});
  final String q, a;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.q,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Icon(_open ? Icons.remove_rounded : Icons.add_rounded,
                    size: 20, color: AppColors.primary),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              Text(widget.a,
                  style: GoogleFonts.poppins(
                      fontSize: 12, height: 1.45, color: AppColors.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }
}
