import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class _Item {
  const _Item(this.key, this.title, this.subtitle, this.def);
  final String key, title, subtitle;
  final bool def;
}

const _sections = <(String, List<_Item>)>[
  ('Channels', [
    _Item('notif_push', 'Push Notifications', 'Alerts on your device', true),
    _Item('notif_email', 'Email', 'Updates to your inbox', true),
    _Item('notif_sms', 'SMS', 'Text-message alerts', false),
  ]),
  ('Activity', [
    _Item('notif_messages', 'Messages',
        'New chat messages from owners & buyers', true),
    _Item('notif_leads', 'New Leads',
        'When someone enquires about your property', true),
    _Item('notif_enquiries', 'Enquiry Updates',
        'Replies and status on your enquiries', true),
    _Item('notif_visits', 'Site Visits', 'Visit requests & reminders', true),
  ]),
  ('Discovery', [
    _Item('notif_pricedrops', 'Price Drops',
        'When a saved property drops in price', true),
    _Item('notif_newlistings', 'New Listings',
        'New homes matching your searches', true),
    _Item('notif_recos', 'Recommendations',
        'Personalised property picks', false),
  ]),
  ('Other', [
    _Item('notif_promos', 'Promotions & Offers',
        'Deals, discounts and announcements', false),
  ]),
];

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final Map<String, bool> _v = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    for (final (_, items) in _sections) {
      for (final it in items) {
        _v[it.key] = p.getBool(it.key) ?? it.def;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _set(String key, bool val) async {
    setState(() => _v[key] = val);
    (await SharedPreferences.getInstance()).setBool(key, val);
    // Mirror to the backend so server-sent pushes respect these toggles.
    try {
      await ref
          .read(apiClientProvider)
          .patch('/me/notif-settings', data: Map<String, bool>.from(_v));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final (title, items) in _sections) ...[
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                            child: Text(title,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkSoft)),
                          ),
                          _card(items),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<_Item> items) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(_tile(items[i]));
      if (i < items.length - 1) {
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

  Widget _tile(_Item it) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.title,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(it.subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Switch(
            value: _v[it.key] ?? it.def,
            activeThumbColor: AppColors.primary,
            onChanged: (val) => _set(it.key, val),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
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
                Text('Notification Settings',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Choose what you hear about',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
