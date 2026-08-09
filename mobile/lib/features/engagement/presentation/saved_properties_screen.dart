import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../property/data/property_view.dart';
import '../data/engagement_repository.dart';
import 'engagement_widgets.dart';

class SavedPropertiesScreen extends ConsumerWidget {
  const SavedPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedPropertiesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            listTopBar(context, 'Saved Properties', "Homes you've saved"),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => emptyState('Could not load.\n$e',
                    Icons.error_outline_rounded),
                data: (rows) => rows.isEmpty
                    ? emptyState(
                        'No saved properties yet.\nTap the ♥ on any listing to save it.',
                        Icons.favorite_border_rounded)
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(savedPropertiesProvider),
                        child: ListView(
                          padding: const EdgeInsets.only(top: 12, bottom: 20),
                          children: [
                            for (final r in rows)
                              propertyRowCard(context, PropertyView(r)),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
