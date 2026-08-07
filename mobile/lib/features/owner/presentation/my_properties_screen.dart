import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../engagement/data/engagement_repository.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';

class MyPropertiesScreen extends ConsumerStatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  ConsumerState<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends ConsumerState<MyPropertiesScreen> {
  int _tab = 0; // 0 = all, 1 = for sale, 2 = for rent

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _refresh() {
    ref
      ..invalidate(myPropertiesProvider)
      ..invalidate(ownerLeadsProvider)
      ..invalidate(saveCountsProvider)
      ..invalidate(ownerVisitsProvider)
      ..invalidate(publishedPropertiesProvider);
  }

  Future<void> _onStatusAction(PropertyView v, String action) async {
    final repo = ref.read(propertyRepositoryProvider);
    final id = v.id;
    switch (action) {
      case 'publish':
      case 'activate':
      case 'reopen':
        await repo.setStatus(id, 'published');
        _refresh();
        _snack('Listing is now active');
      case 'pause':
        await repo.setStatus(id, 'paused');
        _refresh();
        _snack('Listing paused — hidden from search');
      case 'booked':
      case 'sold':
      case 'rented':
        var who = await _pickWho(v, action);
        if (who == null) return; // cancelled
        if (who == '__other__') {
          who = await _askName();
          if (who == null || who.trim().isEmpty) return;
        }
        await repo.setStatus(id, 'closed',
            closeReason: action, closedTo: who.trim());
        _refresh();
        _snack('Marked as ${action[0].toUpperCase()}${action.substring(1)}');
    }
  }

  /// Sheet to pick who the deal closed with — from this listing's enquirers,
  /// or someone from outside. Returns the name, '__other__', or null.
  Future<String?> _pickWho(PropertyView v, String reason) {
    final leads = ref.read(ownerLeadsProvider).asData?.value ?? const [];
    final visits = ref.read(ownerVisitsProvider).asData?.value ?? const [];
    final people = <String, String>{};
    for (final l in [...leads, ...visits]) {
      if ((l['property_id'] ?? '').toString() == v.id) {
        final n = (l['customer_name'] ?? '').toString();
        if (n.isNotEmpty) people[n] = (l['customer_phone'] ?? '').toString();
      }
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppColors.boxBorder,
                      borderRadius: BorderRadius.circular(3))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text('Who did you $reason it to?',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Text('No enquiries on this listing yet.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.inkSoft)),
              ),
            for (final e in people.entries)
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(e.key[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text(e.key,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: e.value.isEmpty
                    ? null
                    : Text(e.value,
                        style: GoogleFonts.poppins(
                            fontSize: 11.5, color: AppColors.inkSoft)),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEFEFF2),
                child: Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.inkSoft, size: 20),
              ),
              title: Text('Someone outside HomeVista',
                  style: GoogleFonts.poppins(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text('Enter their name',
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, color: AppColors.inkSoft)),
              onTap: () => Navigator.pop(ctx, '__other__'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<String?> _askName() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Buyer / tenant name',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Full name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myPropertiesProvider);
    final leads = ref.watch(ownerLeadsProvider).asData?.value ?? const [];
    final leadsByProp = <String, int>{};
    for (final l in leads) {
      final id = (l['property_id'] ?? '').toString();
      if (id.isNotEmpty) leadsByProp[id] = (leadsByProp[id] ?? 0) + 1;
    }
    final savesByProp =
        ref.watch(saveCountsProvider).asData?.value ?? const <String, int>{};
    final visits = ref.watch(ownerVisitsProvider).asData?.value ?? const [];
    final visitsByProp = <String, int>{};
    for (final vv in visits) {
      final id = (vv['property_id'] ?? '').toString();
      if (id.isNotEmpty) visitsByProp[id] = (visitsByProp[id] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Could not load your listings',
                        style: GoogleFonts.poppins(color: AppColors.inkSoft))),
                data: (rows) {
                  final all = rows.map(PropertyView.new).toList();
                  final list = switch (_tab) {
                    1 => all.where((v) => v.purpose == 'sell').toList(),
                    2 => all.where((v) => v.purpose == 'rent').toList(),
                    _ => all,
                  };
                  final sellCount =
                      all.where((v) => v.purpose == 'sell').length;
                  final activeCount = all
                      .where((v) =>
                          (v.raw['status'] ?? '').toString() == 'published')
                      .length;
                  final totalLeads = leads.length;
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref
                        ..invalidate(myPropertiesProvider)
                        ..invalidate(ownerLeadsProvider)
                        ..invalidate(saveCountsProvider)
                        ..invalidate(ownerVisitsProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _summary(all.length, activeCount, totalLeads),
                        const SizedBox(height: 14),
                        _tabs(all.length, sellCount, all.length - sellCount),
                        const SizedBox(height: 14),
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text('No listings here yet.',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.inkSoft)),
                            ),
                          )
                        else
                          for (final v in list)
                            _card(context, v, leadsByProp[v.id] ?? 0,
                                savesByProp[v.id] ?? 0, visitsByProp[v.id] ?? 0),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post-property'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Property',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 16, 6),
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
                  Text('My Properties',
                      style: GoogleFonts.poppins(
                          fontSize: 19, fontWeight: FontWeight.w700)),
                  Text('Manage your listings',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _summary(int total, int active, int leads) {
    Widget cell(String v, String l, IconData i, Color c, Color bg) => Expanded(
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(i, color: c, size: 19),
              ),
              const SizedBox(height: 6),
              Text(v,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text(l,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppColors.inkSoft)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          cell('$total', 'Listings', Icons.home_work_outlined,
              AppColors.primary, AppColors.primarySoft),
          Container(width: 1, height: 40, color: AppColors.border),
          cell('$active', 'Active', Icons.check_circle_outline,
              AppColors.prefGreen, AppColors.prefGreenBg),
          Container(width: 1, height: 40, color: AppColors.border),
          cell('$leads', 'Total Leads', Icons.groups_outlined,
              AppColors.prefOrange, AppColors.prefOrangeBg),
        ],
      ),
    );
  }

  Widget _tabs(int all, int sell, int rent) {
    Widget tab(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? AppColors.primary : AppColors.border),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.ink)),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, 'All ($all)'),
        tab(1, 'For Sale ($sell)'),
        tab(2, 'For Rent ($rent)'),
      ],
    );
  }

  Widget _card(BuildContext context, PropertyView v, int leadCount,
      int saveCount, int visitCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: v.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.primarySoft),
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Builder(builder: (_) {
                        final (label, color) = _statusBadge(v);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(label,
                              style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.inkSoft),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(v.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: AppColors.inkSoft)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(v.priceLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: v.priceColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                _stat(Icons.groups_outlined, '$leadCount', 'Leads'),
                _stat(Icons.favorite_border_rounded, '$saveCount', 'Saved'),
                _stat(Icons.event_outlined, '$visitCount', 'Visits'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: _action(Icons.visibility_outlined, 'View',
                    () => context.push('/property/${v.id}')),
              ),
              Container(width: 1, height: 34, color: AppColors.border),
              Expanded(
                child: _action(Icons.edit_outlined, 'Edit',
                    () => context.push('/edit-property/${v.id}'),
                    color: AppColors.primary),
              ),
              Container(width: 1, height: 34, color: AppColors.border),
              Expanded(
                child: PopupMenuButton<String>(
                  onSelected: (val) => _onStatusAction(v, val),
                  itemBuilder: (_) => _statusMenu(v),
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.tune_rounded,
                            size: 17, color: AppColors.ink),
                        const SizedBox(width: 6),
                        Text('Manage',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusBadge(PropertyView v) {
    final status = (v.raw['status'] ?? 'published').toString();
    switch (status) {
      case 'draft':
        return ('Draft', AppColors.prefOrange);
      case 'paused':
        return ('Paused', AppColors.inkSoft);
      case 'closed':
        final r = (v.attributes['closed_reason'] ?? 'Closed').toString();
        return (
          r.isEmpty ? 'Closed' : '${r[0].toUpperCase()}${r.substring(1)}',
          AppColors.prefBlue
        );
      default:
        return ('Active', AppColors.prefGreen);
    }
  }

  List<PopupMenuEntry<String>> _statusMenu(PropertyView v) {
    final status = (v.raw['status'] ?? 'published').toString();
    PopupMenuItem<String> mi(String val, IconData icon, String label) =>
        PopupMenuItem(
          value: val,
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.ink),
              const SizedBox(width: 10),
              Text(label, style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
        );
    if (status == 'draft') {
      return [mi('publish', Icons.rocket_launch_outlined, 'Publish listing')];
    }
    if (status == 'closed') {
      return [mi('reopen', Icons.refresh_rounded, 'Reopen listing')];
    }
    return [
      status == 'paused'
          ? mi('activate', Icons.play_arrow_rounded, 'Activate listing')
          : mi('pause', Icons.pause_circle_outline, 'Pause listing'),
      const PopupMenuDivider(),
      mi('booked', Icons.event_available_outlined, 'Mark as Booked'),
      mi('sold', Icons.sell_outlined, 'Mark as Sold'),
      mi('rented', Icons.vpn_key_outlined, 'Mark as Rented'),
    ];
  }

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: AppColors.inkSoft),
          const SizedBox(width: 5),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap,
      {Color color = AppColors.ink}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
