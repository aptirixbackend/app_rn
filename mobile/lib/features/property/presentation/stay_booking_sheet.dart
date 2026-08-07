import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../engagement/data/engagement_repository.dart';
import '../data/property_view.dart';

String _money(num v) {
  final s = v.toInt().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Airbnb/OYO-style booking sheet for a Stay listing.
Future<void> showStayBooking(
    BuildContext context, WidgetRef ref, PropertyView v, String? ownerId) {
  final rate = (v.price ?? 0).toDouble();
  final cleaning = num.tryParse(v.attr('cleaning_fee'))?.toDouble() ?? 0;
  final maxG = int.tryParse(v.maxGuests) ?? 4;
  final minNights = int.tryParse(v.attr('min_nights')) ?? 1;
  DateTime? checkIn;
  DateTime? checkOut;
  int guests = 1;
  bool booking = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final nights = (checkIn != null && checkOut != null)
              ? checkOut!.difference(checkIn!).inDays
              : 0;
          final subtotal = rate * nights;
          final serviceFee = subtotal * 0.08;
          final total = subtotal + cleaning + serviceFee;
          final valid = nights >= minNights;

          Future<void> pickIn() async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: ctx,
              initialDate: checkIn ?? now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
            );
            if (d != null) {
              setSheet(() {
                checkIn = d;
                if (checkOut != null && !checkOut!.isAfter(d)) checkOut = null;
              });
            }
          }

          Future<void> pickOut() async {
            final base = checkIn ?? DateTime.now();
            final d = await showDatePicker(
              context: ctx,
              initialDate: base.add(Duration(days: minNights)),
              firstDate: base.add(const Duration(days: 1)),
              lastDate: base.add(const Duration(days: 365)),
            );
            if (d != null) setSheet(() => checkOut = d);
          }

          Future<void> reserve() async {
            if (!valid || booking) return;
            setSheet(() => booking = true);
            final msg =
                'Stay booking · ${_d(checkIn!)} → ${_d(checkOut!)} · $nights '
                'night(s) · $guests guest(s) · ₹${_money(total)} total';
            try {
              await ref
                  .read(engagementRepositoryProvider)
                  .createLead(v.id, ownerId, kind: 'booking', message: msg);
              ref.invalidate(myEnquiriesProvider);
              ref.invalidate(ownerLeadsProvider);
            } catch (_) {
              // preview mode
            }
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.prefGreen),
                    const SizedBox(width: 8),
                    Text('Booking requested',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                content: Text(
                    'Your request for ${_d(checkIn!)} → ${_d(checkOut!)} '
                    '($nights night(s), $guests guest(s)) was sent to the host. '
                    "You'll be notified once it's confirmed.",
                    style: GoogleFonts.poppins(fontSize: 12.5, height: 1.4)),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done')),
                ],
              ),
            );
          }

          Widget dateBox(String label, DateTime? d, VoidCallback onTap) =>
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: GoogleFonts.poppins(
                                fontSize: 10.5, color: AppColors.inkSoft)),
                        const SizedBox(height: 3),
                        Text(d == null ? 'Select' : _d(d),
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    d == null ? AppColors.inkSoft : AppColors.ink)),
                      ],
                    ),
                  ),
                ),
              );

          Widget priceRow(String l, String r, {bool bold = false}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l,
                        style: GoogleFonts.poppins(
                            fontSize: bold ? 14 : 12.5,
                            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                            color: bold ? AppColors.ink : AppColors.inkSoft)),
                    Text(r,
                        style: GoogleFonts.poppins(
                            fontSize: bold ? 15 : 12.5,
                            fontWeight:
                                bold ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              );

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                        color: AppColors.boxBorder,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${_money(rate)}',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    Text(' / night',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.inkSoft)),
                    const Spacer(),
                    if (minNights > 1)
                      Text('Min $minNights nights',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  dateBox('CHECK-IN', checkIn, pickIn),
                  const SizedBox(width: 10),
                  dateBox('CHECK-OUT', checkOut, pickOut),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text('Guests',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      _StepBtn(
                          icon: Icons.remove_rounded,
                          onTap: guests > 1
                              ? () => setSheet(() => guests--)
                              : null),
                      SizedBox(
                        width: 34,
                        child: Text('$guests',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      _StepBtn(
                          icon: Icons.add_rounded,
                          onTap: guests < maxG
                              ? () => setSheet(() => guests++)
                              : null),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (nights > 0) ...[
                  priceRow('₹${_money(rate)} × $nights nights',
                      '₹${_money(subtotal)}'),
                  if (cleaning > 0)
                    priceRow('Cleaning fee', '₹${_money(cleaning)}'),
                  priceRow('Service fee', '₹${_money(serviceFee)}'),
                  const Divider(height: 18, color: AppColors.border),
                  priceRow('Total', '₹${_money(total)}', bold: true),
                  const SizedBox(height: 8),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Select your dates to see the total',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.inkSoft)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: valid && !booking ? reserve : null,
                    child: booking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white))
                        : Text(valid
                            ? 'Reserve'
                            : (nights > 0
                                ? 'Minimum $minNights nights'
                                : 'Select dates')),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: on ? AppColors.primary : AppColors.border),
        ),
        child: Icon(icon,
            size: 18, color: on ? AppColors.primary : AppColors.inkSoft),
      ),
    );
  }
}
