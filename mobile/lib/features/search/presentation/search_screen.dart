import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/location/city_picker.dart';
import '../../../core/location/city_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../property/data/property_filter.dart';
import '../../property/data/property_repository.dart';
import '../../property/data/property_view.dart';
import '../../property/presentation/widgets/property_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialFilter});

  /// Optional preset (e.g. from a Home category tap → filter by property type).
  final PropertyFilter? initialFilter;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late PropertyFilter _filter = widget.initialFilter ?? const PropertyFilter();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _sort() async {
    final s = await showSortSheet(context, _filter.sort);
    if (s != null) setState(() => _filter = _filter.withSort(s));
  }

  Future<void> _filters() async {
    final f =
        await showFilterSheet(context, _filter, localities: _localities());
    if (f != null) setState(() => _filter = f);
  }

  /// Distinct localities in the current (city-scoped) data, for the filter's
  /// multi-select Locality section.
  List<String> _localities() {
    final rows = ref.read(visiblePropertiesProvider).asData?.value ?? const [];
    final set = <String>{
      for (final r in rows) (r['area'] ?? '').toString().trim()
    }..removeWhere((e) => e.isEmpty);
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visiblePropertiesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _message('Could not load listings.\n$e'),
          data: (rows) {
            var list = _filter.apply(rows.map(PropertyView.new).toList());
            final q = _query.trim().toLowerCase();
            if (q.isNotEmpty) {
              list = list
                  .where((v) =>
                      v.title.toLowerCase().contains(q) ||
                      v.location.toLowerCase().contains(q) ||
                      v.propertyType.toLowerCase().contains(q))
                  .toList();
            }
            return Column(
              children: [
                _topBar(context, list.length),
                _searchRow(context),
                const SizedBox(height: 10),
                _filterChips(context),
                if (_filter.hasFilters) _activeFilters(context),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? _message('No properties match your filters.')
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            for (final v in list) PropertyCard(v),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                              child: Text('Showing ${list.length} of ${list.length}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11.5, color: AppColors.inkSoft)),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 'search'),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.inkSoft)),
        ),
      );

  Widget _topBar(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_filter.screenTitle,
                    style: GoogleFonts.poppins(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                Text('$count properties found',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          _headerAction(Icons.favorite_border_rounded,
              onTap: () => context.push('/saved')),
          const SizedBox(width: 8),
          _headerAction(Icons.swap_vert_rounded, label: 'Sort', onTap: _sort),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon,
      {String? label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: AppColors.ink),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search by locality, city or project',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 12.5, color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.inkSoft),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.go('/map'),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Map',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip(Icons.location_on_outlined, ref.watch(selectedCityProvider),
              active: true, onTap: () => showCitySheet(context, ref)),
          _chip(Icons.swap_horiz_rounded, _filter.segmentLabel,
              active: _filter.segment != Segment.all, onTap: _filters),
          _chip(Icons.currency_rupee_rounded, _filter.priceLabel,
              active: _filter.priceIdx != 0, onTap: _filters),
          _chip(Icons.apartment_rounded, _filter.type ?? 'Property Type',
              active: _filter.type != null, onTap: _filters),
          _chip(Icons.tune_rounded, 'Filters',
              active: _filter.hasFilters, dropdown: false, onTap: _filters),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label,
      {bool active = false, bool dropdown = true, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? AppColors.primary : AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.ink)),
              if (dropdown)
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: active ? AppColors.primary : AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeFilters(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('Active:',
              style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft)),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (label, removed) in _filter.activeChips())
                  _removableChip(label, () => setState(() => _filter = removed)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _filter = _filter.cleared()),
            child: Text('Clear All',
                style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _removableChip(String label, VoidCallback onRemove) => Container(
        padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11.5, color: AppColors.primary)),
            const SizedBox(width: 3),
            GestureDetector(
              onTap: onRemove,
              child:
                  const Icon(Icons.close, size: 13, color: AppColors.primary),
            ),
          ],
        ),
      );

}
