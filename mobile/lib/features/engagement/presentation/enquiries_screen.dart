import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../property/data/property_view.dart';
import '../data/engagement_repository.dart';
import 'engagement_widgets.dart';

class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myEnquiriesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            listTopBar(context, 'Enquiries', 'Properties you enquired about'),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => emptyState('Could not load.\n$e',
                    Icons.error_outline_rounded),
                data: (leads) {
                  final withProp = leads
                      .where((l) => l['properties_home'] is Map)
                      .toList();
                  if (withProp.isEmpty) {
                    return emptyState(
                        'No enquiries yet.\nContact an owner from any listing.',
                        Icons.chat_bubble_outline_rounded);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myEnquiriesProvider),
                    child: ListView(
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
                      children: [
                        for (final l in withProp)
                          propertyRowCard(
                            context,
                            PropertyView(
                                Map<String, dynamic>.from(l['properties_home'])),
                            footer:
                                'Enquired via ${l['kind']} · ${timeAgo(l['created_at'])}',
                            footerIcon: Icons.chat_bubble_outline_rounded,
                          ),
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
