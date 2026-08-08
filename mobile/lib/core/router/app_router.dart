import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/phone_verification_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/browse/presentation/segment_landing_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/about_you_screen.dart';
import '../../features/engagement/presentation/enquiries_screen.dart';
import '../../features/engagement/presentation/my_leads_screen.dart';
import '../../features/engagement/presentation/saved_properties_screen.dart';
import '../../features/engagement/presentation/site_visits_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/goal_selection_screen.dart';
import '../../features/owner/presentation/edit_property_screen.dart';
import '../../features/owner/presentation/my_properties_screen.dart';
import '../../features/owner/presentation/owner_profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/property/data/property_filter.dart';
import '../../features/property/presentation/amenities_screen.dart';
import '../../features/property/presentation/photos_media_screen.dart';
import '../../features/property/presentation/pricing_screen.dart';
import '../../features/property/presentation/gallery_screen.dart';
import '../../features/property/presentation/property_detail_screen.dart';
import '../../features/property/presentation/property_details_screen.dart';
import '../../features/property/presentation/property_map_screen.dart';
import '../../features/property/presentation/review_publish_screen.dart';
import '../../features/search/presentation/map_view_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/support/presentation/help_support_screen.dart';
import '../../features/support/presentation/refer_earn_screen.dart';

/// App routes. Auth-based redirects will be added when we build the auth flow.
final appRouterProvider = Provider<GoRouter>((ref) {
  String? idFrom(GoRouterState state) => state.extra as String?;

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => OtpVerificationScreen(
          phoneE164: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) => const PhoneVerificationScreen(),
      ),
      // Goal selection ("How would you like to get started?")
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const GoalSelectionScreen(),
      ),
      // Search path → "Tell us about yourself"
      GoRoute(
        path: '/onboarding/about-you',
        builder: (context, state) => const AboutYouScreen(),
      ),
      // Post path (5-step flow)
      GoRoute(
        path: '/post-property',
        builder: (context, state) => const PropertyDetailsScreen(),
      ),
      GoRoute(
        path: '/post-property/pricing',
        builder: (context, state) {
          final e = state.extra;
          final m = e is Map ? e : const <String, dynamic>{};
          return PricingScreen(
            propertyId: m['id'] as String?,
            type: m['type'] as String?,
            purpose: m['purpose'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/post-property/amenities',
        builder: (context, state) =>
            AmenitiesScreen(propertyId: idFrom(state)),
      ),
      GoRoute(
        path: '/post-property/media',
        builder: (context, state) =>
            PhotosMediaScreen(propertyId: idFrom(state)),
      ),
      GoRoute(
        path: '/post-property/review',
        builder: (context, state) =>
            ReviewPublishScreen(propertyId: idFrom(state)),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            SearchScreen(initialFilter: state.extra as PropertyFilter?),
      ),
      GoRoute(
        path: '/browse/:segment',
        builder: (context, state) => SegmentLandingScreen(
            segment:
                SegmentLandingScreen.parse(state.pathParameters['segment']!)),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapViewScreen(),
      ),
      GoRoute(
        path: '/my-leads',
        builder: (context, state) => const MyLeadsScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedPropertiesScreen(),
      ),
      GoRoute(
        path: '/enquiries',
        builder: (context, state) => const EnquiriesScreen(),
      ),
      GoRoute(
        path: '/visits',
        builder: (context, state) => const SiteVisitsScreen(),
      ),
      GoRoute(
        path: '/my-properties',
        builder: (context, state) => const MyPropertiesScreen(),
      ),
      GoRoute(
        path: '/edit-property/:id',
        builder: (context, state) =>
            EditPropertyScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/refer',
        builder: (context, state) => const ReferEarnScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) =>
            PropertyDetailScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/property/:id/map',
        builder: (context, state) =>
            PropertyMapScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/property/:id/gallery',
        builder: (context, state) =>
            GalleryScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/owner/:id',
        builder: (context, state) => OwnerProfileScreen(
          ownerId: state.pathParameters['id']!,
          ownerName: state.extra as String?,
        ),
      ),
    ],
  );
});
