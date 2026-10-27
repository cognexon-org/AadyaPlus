import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/lab_test_provider.dart';
import '../../providers/location_provider.dart';
import '../pathology/pathology_screen.dart';
import 'diagnostic_booking_screen.dart';

ModuleAccent get labAccent => ModuleAccent.lab;

/// Lab tests and health packages from verified labs, cheapest first. Add
/// several from one lab and book them as one visit or home collection.
class LabTestScreen extends StatefulWidget {
  final String? initialQuery;
  const LabTestScreen({super.key, this.initialQuery});

  @override
  State<LabTestScreen> createState() => _LabTestScreenState();
}

class _LabTestScreenState extends State<LabTestScreen> {
  late final _search = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  bool _homeOnly = false;
  String _kind = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<LabTestProvider>().searchCatalog(
    query: _search.text.trim(),
    homeCollection: _homeOnly,
    pincode: _homeOnly ? context.read<LocationProvider>().pincode : null,
  );

  Future<void> _toggle(Map<String, dynamic> row) async {
    final p = context.read<LabTestProvider>();
    HapticFeedback.selectionClick();
    if (p.inCart(row)) {
      p.removeFromCart(row);
      return;
    }
    if (p.addToCart(row)) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Book from another lab?'),
        content: Text('One booking covers one lab. Your cart has tests from ${p.cartLab?['labName'] ?? 'another lab'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep cart')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Start new cart')),
        ],
      ),
    );
    if (replace == true) p.replaceCart(row);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LabTestProvider>();
    final rows = p.catalog.where((r) => _kind == 'all' || r['kind'] == _kind).toList();
    return ModuleTheme(
      accent: labAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(
          title: 'Lab tests',
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const PathologyScreen())),
              icon: const Icon(LucideIcons.clipboardList, size: 17),
              label: const Text('My tests'),
              style: TextButton.styleFrom(foregroundColor: labAccent.color),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), _load);
                },
                textInputAction: TextInputAction.search,
                cursorColor: labAccent.color,
                style: AppType.sans(fontSize: AppType.body + 1, color: AppColors.textStrong),
                decoration: InputDecoration(
                  hintText: 'Search tests, e.g. CBC, thyroid, vitamin D',
                  prefixIcon: const Icon(LucideIcons.search, size: 19, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.panel,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: labAccent.color, width: 1.5),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final (k, label) in const [('all', 'All'), ('test', 'Tests'), ('package', 'Health packages')]) ...[
                    AppFilterChip(label: label, selected: _kind == k, onTap: () => setState(() => _kind = k)),
                    const SizedBox(width: 8),
                  ],
                  AppFilterChip(
                    label: 'Home collection',
                    selected: _homeOnly,
                    onTap: () {
                      setState(() => _homeOnly = !_homeOnly);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                color: labAccent.color,
                onRefresh: _load,
                child: p.isLoading && p.catalog.isEmpty
                    ? const AppListSkeleton(count: 6)
                    : rows.isEmpty
                    ? ListView(
                        children: [
                          AppEmptyState(
                            illustration: p.error != null ? Illustrations.offline : Illustrations.labReport,
                            title: p.error != null ? 'Couldn’t load tests' : 'No tests match that',
                            message: p.error ?? 'Try a different name, or turn off home collection.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => AppEntrance(
                          index: i.clamp(0, 8),
                          child: _TestTile(row: rows[i], added: p.inCart(rows[i]), onToggle: () => _toggle(rows[i])),
                        ),
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const LabCartBar(),
      ),
    );
  }
}

class _TestTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool added;
  final VoidCallback onToggle;
  const _TestTile({required this.row, required this.added, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final item = mapOf(row['item']);
    final package = row['kind'] == 'package';
    final name = ((package ? item['packageName'] : item['testName']) ?? 'Test').toString();
    final included = package && item['testCodes'] is List ? (item['testCodes'] as List).length : 0;
    final facts = [
      if (row['homeCollectionAvailable'] == true) 'Home pickup',
      if (package && included > 0) '$included tests included',
      if (item['fastingRequired'] == true) 'Fasting needed',
      if (!package && (item['sampleType'] ?? '').toString().isNotEmpty) sentenceCase(item['sampleType'].toString()),
      if (item['reportTime'] != null) 'Report in ${item['reportTime']} h',
    ];
    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: added ? labAccent.veryLight : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: added ? labAccent.color : AppColors.borderStrong, width: added ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: added ? Colors.white : labAccent.veryLight, borderRadius: BorderRadius.circular(13)),
            child: Icon(package ? LucideIcons.packageOpen : LucideIcons.flaskConical, size: 20, color: labAccent.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (row['labName'] ?? 'Lab').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: labAccent.color),
                      ),
                    ),
                  ],
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(facts.join(' · '), style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(appRupees(item['price']), style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              const SizedBox(height: 8),
              AppPressable(
                onTap: onToggle,
                semanticLabel: added ? 'Remove $name' : 'Add $name',
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: added ? labAccent.color : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: labAccent.color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(added ? LucideIcons.check : LucideIcons.plus, size: 14, color: added ? Colors.white : labAccent.color),
                      const SizedBox(width: 4),
                      Text(
                        added ? 'Added' : 'Add',
                        style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w800, color: added ? Colors.white : labAccent.color),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The test cart, floating while it has anything in it.
class LabCartBar extends StatelessWidget {
  const LabCartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LabTestProvider>();
    final n = p.cart.length;
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      transitionBuilder: (c, a) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: AppMotion.enter)),
        child: c,
      ),
      child: n == 0
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppPressable(
                  onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const DiagnosticBookingScreen())),
                  scale: 0.98,
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: labAccent.color, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.shadowElevated),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.flaskConical, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$n test${n == 1 ? '' : 's'} · ${p.cartLab?['labName'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.sans(fontSize: AppType.caption, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                              Text(appRupees(p.cartSubtotal), style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        ),
                        Text('Book', style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronRight, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
