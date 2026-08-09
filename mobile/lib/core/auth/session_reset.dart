import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/engagement/data/engagement_repository.dart';
import '../../features/property/data/property_repository.dart';
import 'mock_auth.dart';

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
