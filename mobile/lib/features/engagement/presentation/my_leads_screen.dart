import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../property/data/property_view.dart';
import '../data/engagement_repository.dart';
import 'engagement_widgets.dart';

class MyLeadsScreen extends ConsumerStatefulWidget {
  const MyLeadsScreen({super.key});

  @override
  ConsumerState<MyLeadsScreen> createState() => _MyLeadsScreenState();
}

class _MyLeadsScreenState extends ConsumerState<MyLeadsScreen> {
  int _tab = 0;

  static final _compactText =
      GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600);

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _refresh() {
    ref
      ..invalidate(ownerLeadsProvider)
      ..invalidate(ownerVisitsProvider)
      ..invalidate(myEnquiriesProvider)
      ..invalidate(myVisitsProvider)
      ..invalidate(notificationCountProvider);
  }

  Future<void> _setLead(String id, String status, String msg) async {
    await ref.read(engagementRepositoryProvider).updateLeadStatus(id, status);
    _refresh();
    _snack(msg);
  }

  Future<void> _setVisit(String id, String status, String msg) async {
    await ref.read(engagementRepositoryProvider).updateVisitStatus(id, status);
    _refresh();
    _snack(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            listTopBar(context, 'My Leads', 'Requests on your properties'),
            _tabs(),
            Expanded(child: _tab == 0 ? _enquiries() : _visits()),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 'leads'),
    );
  }

  Widget _tabs() {
    Widget tab(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: sel ? AppColors.primary : AppColors.border),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(children: [tab(0, 'Enquiries'), tab(1, 'Site Visits')]),
    );
  }

  Widget _enquiries() {
    final async = ref.watch(ownerLeadsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          emptyState('Could not load leads.\n$e', Icons.error_outline_rounded),
      data: (leads) => leads.isEmpty
          ? emptyState(
              'No enquiries yet.\nEnquiries & bookings from buyers\n& tenants show up here.',
              Icons.groups_outlined)
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                children: [for (final l in leads) _leadCard(l)],
              ),
            ),
    );
  }

  Widget _visits() {
    final async = ref.watch(ownerVisitsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          emptyState('Could not load visits.\n$e', Icons.error_outline_rounded),
      data: (visits) => visits.isEmpty
          ? emptyState(
              'No site visits yet.\nVisit requests appear here for you\nto accept or decline.',
              Icons.event_outlined)
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                children: [for (final v in visits) _visitCard(v)],
              ),
            ),
    );
  }

  // ---- cards -------------------------------------------------------------
  Widget _leadCard(Map<String, dynamic> lead) {
    final v = _prop(lead);
    final kind = (lead['kind'] ?? 'enquiry').toString();
    final status = (lead['status'] ?? 'new').toString();
    final isBooking = kind == 'booking';
    final customer = (lead['customer_name'] ?? 'Guest User').toString();
    final phone = (lead['customer_phone'] ?? '').toString();
    final message = (lead['message'] ?? '').toString();

    return _card([
      _header(v, status),
      _divider(),
      _customerRow(customer, phone, kind, lead['created_at']),
      if (isBooking && message.isNotEmpty) ...[
        const SizedBox(height: 8),
        _msgBox(message),
      ],
      const SizedBox(height: 12),
      if (isBooking)
        _pending(status == 'new')
            ? _acceptReject(
                () => _setLead(lead['id'].toString(), 'confirmed',
                    'Booking accepted'),
                () => _setLead(
                    lead['id'].toString(), 'rejected', 'Booking declined'))
            : _statusLine(status)
      else
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _snack(phone.isEmpty
                    ? 'No phone number on this lead'
                    : 'Calling $phone…'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42), textStyle: _compactText),
                child: const Text('Call'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: status == 'new'
                    ? () => _setLead(
                        lead['id'].toString(), 'contacted', 'Marked contacted')
                    : null,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42), textStyle: _compactText),
                child: Text(status == 'new' ? 'Mark Contacted' : 'Contacted'),
              ),
            ),
          ],
        ),
    ]);
  }

  Widget _visitCard(Map<String, dynamic> visit) {
    final v = _prop(visit);
    final status = (visit['status'] ?? 'requested').toString();
    final customer = (visit['customer_name'] ?? 'Guest User').toString();
    final phone = (visit['customer_phone'] ?? '').toString();
    final date = (visit['scheduled_for'] ?? '').toString();

    return _card([
      _header(v, status),
      _divider(),
      _customerRow(customer, phone, 'site visit', visit['created_at']),
      if (date.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.event_outlined, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Requested for $date',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
      const SizedBox(height: 12),
      if (status == 'requested')
        _acceptReject(
          () => _setVisit(visit['id'].toString(), 'confirmed', 'Visit accepted'),
          () => _setVisit(visit['id'].toString(), 'cancelled', 'Visit declined'),
        )
      else if (status == 'confirmed')
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _snack(
                    phone.isEmpty ? 'No phone number' : 'Calling $phone…'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42), textStyle: _compactText),
                child: const Text('Call'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    _setVisit(visit['id'].toString(), 'done', 'Visit completed'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42), textStyle: _compactText),
                child: const Text('Mark Done'),
              ),
            ),
          ],
        )
      else
        _statusLine(status),
    ]);
  }

  // ---- shared pieces -----------------------------------------------------
  bool _pending(bool b) => b;

  PropertyView? _prop(Map<String, dynamic> m) {
    final p = m['properties_home'];
    return p is Map ? PropertyView(Map<String, dynamic>.from(p)) : null;
  }

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );

  Widget _header(PropertyView? v, String status) => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: v == null
                  ? Container(color: AppColors.primarySoft)
                  : Image(
                      image: v.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.primarySoft)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v?.title ?? 'Property',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(v?.location ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          _statusBadge(status),
        ],
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: AppColors.border),
      );

  Widget _customerRow(
      String customer, String phone, String kind, Object? createdAt) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primarySoft,
          child: Text(customer.isNotEmpty ? customer[0] : 'G',
              style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(customer,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  _kindBadge(kind),
                ],
              ),
              Text(phone.isEmpty ? 'contacted via app' : phone,
                  style: GoogleFonts.poppins(
                      fontSize: 10.5, color: AppColors.inkSoft)),
            ],
          ),
        ),
        Text(timeAgo(createdAt),
            style: GoogleFonts.poppins(
                fontSize: 10.5, color: AppColors.inkSoft)),
      ],
    );
  }

  Widget _msgBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message,
            style: GoogleFonts.poppins(
                fontSize: 11.5, height: 1.35, color: AppColors.ink)),
      );

  Widget _acceptReject(VoidCallback onAccept, VoidCallback onReject) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
              label: const Text('Decline', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42), textStyle: _compactText,
                  side: const BorderSide(color: Color(0xFFF1C6C6))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Accept'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(42), textStyle: _compactText),
            ),
          ),
        ],
      );

  Widget _statusLine(String status) {
    final label = switch (status) {
      'confirmed' => 'Accepted',
      'rejected' || 'cancelled' => 'Declined',
      'done' => 'Completed',
      'contacted' => 'Contacted',
      'closed' => 'Closed',
      _ => status,
    };
    final (c, bg) = _statusStyle(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: c)),
    );
  }

  (Color, Color) _statusStyle(String s) {
    switch (s) {
      case 'confirmed':
      case 'contacted':
        return (AppColors.prefGreen, AppColors.prefGreenBg);
      case 'done':
        return (AppColors.prefBlue, AppColors.prefBlueBg);
      case 'rejected':
      case 'cancelled':
      case 'closed':
        return (const Color(0xFFE23D3D), const Color(0xFFFDECEC));
      default:
        return (AppColors.primary, AppColors.primarySoft);
    }
  }

  Widget _statusBadge(String status) {
    final label = switch (status) {
      'new' || 'requested' => 'Pending',
      'confirmed' => 'Accepted',
      'contacted' => 'Contacted',
      'rejected' || 'cancelled' => 'Declined',
      'done' => 'Completed',
      'closed' => 'Closed',
      _ => status,
    };
    final (c, bg) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 9.5, fontWeight: FontWeight.w600, color: c)),
    );
  }

  Widget _kindBadge(String kind) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(5)),
        child: Text(kind,
            style: GoogleFonts.poppins(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      );
}
