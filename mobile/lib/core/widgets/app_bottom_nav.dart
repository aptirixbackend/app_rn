import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/mock_auth.dart';
import '../theme/app_colors.dart';

/// Shared bottom navigation. The center "+" opens the posting flow.
/// The 4th tab is role-aware: owners get "My Leads", searchers get "Map".
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, required this.current});

  /// 'home' | 'search' | 'leads' | 'map' | 'profile'
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(userRoleProvider).asData?.value == 'owner';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(context, Icons.home_rounded, 'Home', current == 'home',
                  () => context.go('/home')),
              _item(context, Icons.search_rounded, 'Search',
                  current == 'search', () => context.go('/search')),
              _post(context),
              if (isOwner)
                _item(context, Icons.groups_outlined, 'My Leads',
                    current == 'leads', () => context.go('/my-leads'))
              else
                _item(context, Icons.map_outlined, 'Map', current == 'map',
                    () => context.go('/map')),
              _item(context, Icons.person_outline_rounded, 'Profile',
                  current == 'profile', () => context.go('/profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, bool selected,
      VoidCallback onTap) {
    final color = selected ? AppColors.primary : AppColors.inkSoft;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _post(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/post-property'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 2),
            Text('Post Property',
                style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
