import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/mock_auth.dart';
import '../../../core/notifications/notif_read_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../engagement/data/engagement_repository.dart';
import '../../engagement/presentation/engagement_widgets.dart';
import '../../property/data/property_view.dart';

class _Notif {
  _Notif(this.icon, this.color, this.bg, this.title, this.subtitle, this.time,
      this.propertyId);
  final IconData icon;
  final Color color, bg;
  final String title, subtitle, time;
  final String? propertyId;
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening this page marks everything as read → clears the bell badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notifLastReadProvider.notifier).markReadNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(userRoleProvider).asData?.value == 'owner';
    final leadsAsync =
        isOwner ? ref.watch(ownerLeadsProvider) : ref.watch(myEnquiriesProvider);
    final visitsAsync =
        isOwner ? ref.watch(ownerVisitsProvider) : ref.watch(myVisitsProvider);
    final leads = leadsAsync.asData?.value;
    final visits = visitsAsync.asData?.value;
    final loading = leads == null || visits == null;

    final items = <_Notif>[];
    if (!loading) {
      for (final l in leads) {
        items.add(_leadNotif(l, isOwner));
      }
      for (final v in visits) {
        items.add(_visitNotif(v, isOwner));
      }
      items.sort((a, b) => b.time.compareTo(a.time));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? emptyState(
                          'No notifications yet.\nYour activity will show up here.',
                          Icons.notifications_none_rounded)
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref
                              ..invalidate(ownerLeadsProvider)
                              ..invalidate(ownerVisitsProvider)
                              ..invalidate(myEnquiriesProvider)
                              ..invalidate(myVisitsProvider);
                          },
                          child: ListView(
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            children: [for (final n in items) _row(context, n)],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  PropertyView? _prop(Map<String, dynamic> row) {
    final p = row['properties_home'];
    return p is Map ? PropertyView(Map<String, dynamic>.from(p)) : null;
  }

  _Notif _leadNotif(Map<String, dynamic> l, bool isOwner) {
    final title = _prop(l)?.title ?? 'a property';
    final kind = (l['kind'] ?? 'enquiry').toString();
    final status = (l['status'] ?? 'new').toString();
    final customer = (l['customer_name'] ?? 'Someone').toString();
    final time = (l['created_at'] ?? '').toString();
    final id = _prop(l)?.id;
    final isBooking = kind == 'booking';
    if (isOwner) {
      return _Notif(
          isBooking ? Icons.event_available_rounded : Icons.groups_rounded,
          AppColors.primary,
          AppColors.primarySoft,
          isBooking ? 'New booking request' : 'New $kind enquiry',
          '$customer is interested in $title', time, id);
    }
    // searcher — reflect the owner's response
    if (isBooking && status == 'confirmed') {
      return _Notif(Icons.check_circle_outline, AppColors.prefGreen,
          AppColors.prefGreenBg, 'Booking confirmed',
          'Your booking for $title was accepted', time, id);
    }
    if (isBooking && status == 'rejected') {
      return _Notif(Icons.cancel_outlined, const Color(0xFFE23D3D),
          const Color(0xFFFDECEC), 'Booking declined',
          'Your booking for $title was declined', time, id);
    }
    return _Notif(Icons.chat_bubble_outline_rounded, AppColors.primary,
        AppColors.primarySoft, isBooking ? 'Booking requested' : 'Enquiry sent',
        isBooking ? 'You requested to book $title' : 'You enquired about $title',
        time, id);
  }

  _Notif _visitNotif(Map<String, dynamic> v, bool isOwner) {
    final title = _prop(v)?.title ?? 'a property';
    final date = (v['scheduled_for'] ?? '').toString();
    final on = date.isNotEmpty ? ' on $date' : '';
    final status = (v['status'] ?? 'requested').toString();
    final customer = (v['customer_name'] ?? 'Someone').toString();
    final time = (v['created_at'] ?? '').toString();
    final id = _prop(v)?.id;
    if (isOwner) {
      return _Notif(Icons.event_available_outlined, AppColors.prefOrange,
          AppColors.prefOrangeBg, 'New site visit request',
          '$customer wants to visit $title$on', time, id);
    }
    // searcher — reflect the owner's decision
    final (IconData icon, Color c, Color bg, String head) = switch (status) {
      'confirmed' => (
          Icons.check_circle_outline,
          AppColors.prefGreen,
          AppColors.prefGreenBg,
          'Site visit confirmed'
        ),
      'cancelled' => (
          Icons.cancel_outlined,
          const Color(0xFFE23D3D),
          const Color(0xFFFDECEC),
          'Site visit declined'
        ),
      'done' => (
          Icons.verified_outlined,
          AppColors.prefBlue,
          AppColors.prefBlueBg,
          'Site visit completed'
        ),
      _ => (
          Icons.event_available_outlined,
          AppColors.prefOrange,
          AppColors.prefOrangeBg,
          'Site visit requested'
        ),
    };
    return _Notif(icon, c, bg, head, '$title$on', time, id);
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications',
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                Text('Your latest activity',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          IconButton(
              onPressed: () => context.push('/notification-settings'),
              icon: const Icon(Icons.settings_outlined, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _Notif n) {
    return InkWell(
      onTap: n.propertyId != null
          ? () => context.push('/property/${n.propertyId}')
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(color: n.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(n.icon, color: n.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(n.subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, height: 1.35, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(timeAgo(n.time),
                style: GoogleFonts.poppins(
                    fontSize: 10.5, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
