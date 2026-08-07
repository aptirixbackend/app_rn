import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'city_store.dart';

/// Bottom sheet to switch the active city.
Future<void> showCitySheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(selectedCityProvider);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: AppColors.boxBorder,
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text('Select city',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.my_location_rounded,
                color: AppColors.primary),
            title: Text('Use current location',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            subtitle: Text('Detect the nearest city',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.inkSoft)),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                    content: Text('Detecting your location…')));
              final city =
                  await ref.read(selectedCityProvider.notifier).detectNearestCity();
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(
                  content: Text(city != null
                      ? 'Showing properties in $city (nearest city)'
                      : 'Could not detect location — please pick a city')));
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          for (final c in kCities)
            ListTile(
              leading: Icon(Icons.location_city_rounded,
                  color: c == current ? AppColors.primary : AppColors.inkSoft),
              title: Text(c,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                          c == current ? FontWeight.w600 : FontWeight.w400,
                      color: c == current ? AppColors.primary : AppColors.ink)),
              trailing: c == current
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref.read(selectedCityProvider.notifier).set(c);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
