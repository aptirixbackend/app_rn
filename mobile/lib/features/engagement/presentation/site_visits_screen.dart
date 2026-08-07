import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../property/data/property_view.dart';
import '../data/engagement_repository.dart';
import 'engagement_widgets.dart';

class SiteVisitsScreen extends ConsumerWidget {
  const SiteVisitsScreen({super.key});

  Widget _visitRow(BuildContext context, Map<String, dynamic> vis) {
    final status = (vis['status'] ?? 'requested').toString();
    final (String label, Color color, IconData icon) = switch (status) {
      'confirmed' => (
          'Confirmed by owner',
          AppColors.prefGreen,
          Icons.check_circle_outline
        ),
      'cancelled' => (
          'Declined by owner',
          const Color(0xFFE23D3D),
          Icons.cancel_outlined
        ),
      'done' =>
        ('Visit completed', AppColors.prefBlue, Icons.verified_outlined),
      _ => (
          'Pending owner approval',
          AppColors.prefOrange,
          Icons.hourglass_bottom_rounded
        ),
    };
    return propertyRowCard(
      context,
      PropertyView(Map<String, dynamic>.from(vis['properties_home'])),
      footer: 'Visit ${vis['scheduled_for'] ?? '—'} · $label',
      footerIcon: icon,
      footerColor: color,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myVisitsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            listTopBar(context, 'Site Visits', 'Your scheduled property visits'),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => emptyState('Could not load.\n$e',
                    Icons.error_outline_rounded),
                data: (visits) {
                  final withProp = visits
                      .where((v) => v['properties_home'] is Map)
                      .toList();
                  if (withProp.isEmpty) {
                    return emptyState(
                        'No site visits yet.\nSchedule one from any listing.',
                        Icons.event_outlined);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myVisitsProvider),
                    child: ListView(
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
                      children: [
                        for (final vis in withProp)
                          _visitRow(context, vis),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
