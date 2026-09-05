import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/engagement/data/engagement_repository.dart';
import '../../features/property/data/property_repository.dart';
import 'mock_auth.dart';

/// Promote the signed-in user to an **owner** the moment they list a property
/// (post or save a draft). Their role drives the bottom tabs and profile, so
/// this flips them from searcher → owner (My Leads tab, owner profile with My
/// Properties, edit access). No-op if they're already an owner.
Future<void> becomeOwner(WidgetRef ref) async {
  final auth = ref.read(mockAuthProvider);
  if (await auth.goal() == 'post') return;
  await auth.setGoal('post');
  ref
    ..invalidate(userRoleProvider)
    ..invalidate(myPropertiesProvider);
}

/// Invalidate every provider that is scoped to the signed-in user, so a
/// login/logout/account-switch never shows the previous user's cached data
/// (profile, favorites, enquiries, visits, listings, notifications).
void invalidateUserData(WidgetRef ref) {
  ref
    ..invalidate(userRoleProvider)
    ..invalidate(userNameProvider)
    ..invalidate(userEmailProvider)
    ..invalidate(userPhoneProvider)
    ..invalidate(userCityProvider)
    ..invalidate(userAvatarProvider)
    ..invalidate(favoriteIdsProvider)
    ..invalidate(savedPropertiesProvider)
    ..invalidate(myEnquiriesProvider)
    ..invalidate(myVisitsProvider)
    ..invalidate(myEnquiredIdsProvider)
    ..invalidate(myVisitedIdsProvider)
    ..invalidate(ownerLeadsProvider)
    ..invalidate(ownerVisitsProvider)
    ..invalidate(saveCountsProvider)
    ..invalidate(notificationCountProvider)
    ..invalidate(myPropertiesProvider);
}
