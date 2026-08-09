import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/mock_auth.dart';
import '../../../core/auth/session_reset.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../engagement/data/engagement_repository.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/seen_store.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  /// Pick a photo, upload it, and set it as the user's avatar everywhere.
  Future<void> _pickAndSetAvatar(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (x == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Uploading photo…')));
    try {
      final bytes = await x.readAsBytes();
      final repo = ref.read(propertyRepositoryProvider);
      final auth = ref.read(mockAuthProvider);
      final uid = await auth.userId();
      final url = await repo.uploadMedia(bytes, 'avatar_$uid.jpg');
      if (url == null || url.isEmpty) throw Exception('upload failed');
      // Cache-bust so a re-upload to the same path refreshes on screen.
      final clean = url.endsWith('?') ? url.substring(0, url.length - 1) : url;
      final busted = '$clean?v=${DateTime.now().millisecondsSinceEpoch}';
      await auth.setProfile(avatar: busted);
      ref.invalidate(userAvatarProvider);
      try {
        await repo.updateMyProfile({'avatar_url': busted}); // best-effort DB save
      } catch (_) {}
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Could not upload photo. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(userRoleProvider).asData?.value == 'owner';
    final storedName = ref.watch(userNameProvider).asData?.value;
    final name = (storedName != null && storedName.trim().isNotEmpty)
        ? storedName.trim()
        : 'RentoRent User';
    final email = ref.watch(userEmailProvider).asData?.value ?? '';
    final phoneRaw = ref.watch(userPhoneProvider).asData?.value ?? '';
    final phone = (phoneRaw.isEmpty || phoneRaw == 'google') ? '' : phoneRaw;
    final city = ref.watch(userCityProvider).asData?.value ?? '';
    final avatar = ref.watch(userAvatarProvider).asData?.value;

    final savedCount = ref.watch(favoriteIdsProvider).asData?.value.length ?? 0;
    final visitCount = ref.watch(myVisitsProvider).asData?.value.length ?? 0;
    final enqCount = ref.watch(myEnquiriesProvider).asData?.value.length ?? 0;
    final leadCount = ref.watch(ownerLeadsProvider).asData?.value.length ?? 0;
    final propCount =
        ref.watch(myPropertiesProvider).asData?.value.length ?? 0;
    final ownerVisitCount =
        ref.watch(ownerVisitsProvider).asData?.value.length ?? 0;
    final recentCount = ref.watch(seenIdsProvider).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(context, isOwner),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileCard(
                        context, ref, isOwner, name, phone, email, city, avatar),
                    const SizedBox(height: 18),
                    if (isOwner)
                      ..._ownerBody(
                          context, propCount, leadCount, ownerVisitCount)
                    else
                      ..._searcherBody(context, savedCount, recentCount,
                          visitCount, enqCount),
                    const SizedBox(height: 18),
                    _logout(context, ref),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 'profile'),
    );
  }

  // ---- header ------------------------------------------------------------
  Widget _topBar(BuildContext context, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Profile',
                    style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                Text(
                    isOwner
                        ? 'Manage your account and business'
                        : 'Manage your account and preferences',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const NotificationBell(),
          IconButton(
              onPressed: () => context.push('/notification-settings'),
              icon: const Icon(Icons.settings_outlined, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, WidgetRef ref, bool isOwner,
      String name, String phone, String email, String city, String? avatar) {
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    return GestureDetector(
      onTap: () => context.push('/edit-profile'),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFEEEBFF), Color(0xFFF4F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _pickAndSetAvatar(context, ref),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      hasAvatar ? NetworkImage(avatar) : null,
                  child: hasAvatar
                      ? null
                      : Text(name.isNotEmpty ? name[0] : 'U',
                          style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    if (isOwner)
                      const Icon(Icons.verified_rounded,
                          size: 18, color: AppColors.primary)
                    else
                      GestureDetector(
                        onTap: () => context.push('/edit-profile'),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text('Edit',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                  ],
                ),
                if (isOwner) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('Property Owner',
                        style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ],
                const SizedBox(height: 8),
                if (phone.isNotEmpty) _contact(Icons.phone_outlined, phone),
                if (email.isNotEmpty)
                  _contact(Icons.mail_outline_rounded, email),
                if (city.isNotEmpty)
                  _contact(Icons.location_on_outlined, city),
                if (phone.isEmpty && email.isEmpty && city.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Tap to add your contact details',
                        style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary)),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
        ],
      ),
      ),
    );
  }

  Widget _contact(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.inkSoft),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, color: AppColors.ink)),
            ),
          ],
        ),
      );

  // ---- owner -------------------------------------------------------------
  List<Widget> _ownerBody(
      BuildContext context, int propCount, int leadCount, int visitCount) {
    return [
      _statsCard([
        _stat(Icons.home_rounded, AppColors.primary, AppColors.primarySoft,
            '$propCount', 'Properties', 'Active'),
        _stat(Icons.groups_rounded, AppColors.prefGreen, AppColors.prefGreenBg,
            '$leadCount', 'Total Leads', 'All Time'),
        _stat(Icons.event_outlined, AppColors.prefOrange,
            AppColors.prefOrangeBg, '$visitCount', 'Site Visits', 'All Time'),
      ]),
      const SizedBox(height: 16),
      _card([
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text('Quick Actions',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Row(
          children: [
            _quick(context, Icons.home_outlined, AppColors.primarySoft,
                AppColors.primary, 'My Properties',
                onTap: () => context.push('/my-properties')),
            _quick(context, Icons.groups_outlined, AppColors.prefGreenBg,
                AppColors.prefGreen, 'My Leads',
                onTap: () => context.push('/my-leads')),
            _quick(context, Icons.add_home_outlined, AppColors.prefOrangeBg,
                AppColors.prefOrange, 'Add Property',
                onTap: () => context.push('/post-property')),
            _quick(context, Icons.notifications_none_rounded,
                AppColors.prefPinkBg, AppColors.prefPink, 'Alerts',
                onTap: () => context.push('/notifications')),
            _quick(context, Icons.help_outline_rounded, AppColors.prefBlueBg,
                AppColors.prefBlue, 'Help',
                onTap: () => context.push('/help')),
          ],
        ),
      ]),
      const SizedBox(height: 16),
      _menuCard([
        _tile(context, Icons.edit_outlined, 'Edit Profile',
            'Update your personal information',
            onTap: () => context.push('/edit-profile')),
        _tile(context, Icons.home_work_outlined, 'My Properties',
            'View and manage your listings',
            onTap: () => context.push('/my-properties')),
        _tile(context, Icons.groups_outlined, 'My Leads',
            'Track enquiries on your listings',
            onTap: () => context.push('/my-leads')),
        _tile(context, Icons.notifications_none_rounded,
            'Notification Settings', 'Manage your notifications',
            onTap: () => context.push('/notification-settings')),
        _tile(context, Icons.help_outline_rounded, 'Help & Support',
            'Get help and contact support',
            onTap: () => context.push('/help')),
      ]),
      const SizedBox(height: 16),
      _helpCard(context),
    ];
  }

  // ---- searcher ----------------------------------------------------------
  List<Widget> _searcherBody(BuildContext context, int savedCount,
      int recentCount, int visitCount, int enqCount) {
    return [
      _statsCard([
        _stat(Icons.favorite_border_rounded, AppColors.primary,
            AppColors.primarySoft, '$savedCount', 'Saved', 'Properties'),
        _stat(Icons.remove_red_eye_outlined, AppColors.prefGreen,
            AppColors.prefGreenBg, '$recentCount', 'Recent', 'Views'),
        _stat(Icons.event_outlined, AppColors.prefOrange,
            AppColors.prefOrangeBg, '$visitCount', 'Site Visits', 'Scheduled'),
        _stat(Icons.description_outlined, AppColors.prefBlue,
            AppColors.prefBlueBg, '$enqCount', 'Enquiries', 'Sent'),
      ]),
      const SizedBox(height: 16),
      _menuCard([
        _tile(context, Icons.favorite_border_rounded, 'Saved Properties',
            'View your saved homes',
            onTap: () => context.push('/saved')),
        _tile(context, Icons.event_outlined, 'Site Visits',
            'Manage your scheduled visits',
            onTap: () => context.push('/visits')),
        _tile(context, Icons.chat_bubble_outline_rounded, 'Enquiries',
            'Track your property enquiries',
            onTap: () => context.push('/enquiries')),
      ]),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('Account & Preferences',
            style:
                GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      _menuCard([
        _tile(context, Icons.person_outline_rounded, 'Personal Information',
            'Update your personal details',
            onTap: () => context.push('/edit-profile')),
        _tile(context, Icons.notifications_none_rounded,
            'Notification Settings', 'Manage notifications',
            onTap: () => context.push('/notification-settings')),
        _tile(context, Icons.help_outline_rounded, 'Help & Support',
            'Get help and contact support',
            onTap: () => context.push('/help')),
      ]),
      const SizedBox(height: 16),
      _referCard(context),
    ];
  }

  // ---- shared pieces -----------------------------------------------------
  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _statsCard(List<Widget> stats) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      children.add(Expanded(child: stats[i]));
      if (i < stats.length - 1) {
        children.add(Container(width: 1, height: 40, color: AppColors.border));
      }
    }
    return _card([Row(children: children)]);
  }

  Widget _stat(IconData icon, Color color, Color bg, String value,
      String label, String sub) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 6),
        Text(value,
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 10, fontWeight: FontWeight.w500)),
        Text(sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 9, color: AppColors.inkSoft)),
      ],
    );
  }

  Widget _quick(BuildContext context, IconData icon, Color bg, Color color,
      String label, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => _soon(context),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.poppins(
                    fontSize: 9, height: 1.1, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(const Divider(height: 1, color: AppColors.border));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle,
      {Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _soon(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            if (trailing != null) ...[trailing, const SizedBox(width: 8)],
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _helpCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.prefGreenBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.prefGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.headset_mic_outlined,
                color: AppColors.prefGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need Help?',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.prefGreen)),
                Text("We're here to help you 24/7",
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/help'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.prefGreen.withValues(alpha: 0.4))),
              child: Text('Contact Support',
                  style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.prefGreen)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.card_giftcard_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Refer & Earn',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Invite your friends and earn exciting rewards',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.inkSoft)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push('/refer'),
                  child: Row(
                    children: [
                      Text('Invite Now',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logout(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        // Clears the backend JWT + the entire local session, and drops all
        // cached per-user data so nothing leaks to the next login.
        await ref.read(authServiceProvider).signOut();
        invalidateUserData(ref);
        if (context.mounted) context.go('/sign-in');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text('Logout',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
