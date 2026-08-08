import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../data/onboarding_repository.dart';

class GoalSelectionScreen extends ConsumerWidget {
  const GoalSelectionScreen({super.key});

  Future<void> _select(
      BuildContext context, WidgetRef ref, String goal) async {
    final auth = ref.read(mockAuthProvider);
    await auth.setGoal(goal);
    if (goal == 'post') await auth.setOnboarded();
    try {
      await ref.read(onboardingRepositoryProvider).setPrimaryGoal(goal);
    } catch (_) {
      // Ignore if backend/Supabase unavailable — still navigate.
    }
    if (!context.mounted) return;
    context.go(goal == 'post' ? '/post-property' : '/onboarding/about-you');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _logo(),
                      const SizedBox(height: 22),
                      Text(
                        'How would you like to\nget started?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choose an option below to continue\nyour journey with us',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _GoalCard(
                          title: 'Post a Home',
                          subtitle:
                              'List your property and\nconnect with potential\ntenants or buyers',
                          accent: AppColors.primary,
                          cardColor: AppColors.postCard,
                          image: 'assets/images/for_home.png',
                          onTap: () => _select(context, ref, 'post'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _GoalCard(
                          title: 'Search a Home',
                          subtitle:
                              'Explore thousands of\nverified properties that\nmatch your needs',
                          accent: AppColors.green,
                          cardColor: AppColors.searchCard,
                          image: 'assets/images/search_home.png',
                          onTap: () => _select(context, ref, 'search'),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      _personalizeNote(),
                      const SizedBox(height: 12),
                      Image.asset(
                        'assets/images/bottom_design.png',
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _logo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.home_rounded, color: AppColors.primary, size: 26),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(text: 'Rento', style: TextStyle(color: AppColors.ink)),
              TextSpan(
                  text: 'Rent', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _personalizeNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            "We'll personalize your experience based\non your choice",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.cardColor,
    required this.image,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Color cardColor;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration:
                          BoxDecoration(color: accent, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 132,
              height: double.infinity,
              child: Image.asset(image, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }
}
