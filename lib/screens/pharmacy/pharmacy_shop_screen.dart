import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/pharmacy_provider.dart';
import 'nearby_pharmacy_screen.dart';
import 'pharmacy_widgets.dart';

/// The selected pharmacy's live catalog: search, form and Rx filters, and
/// add to cart. Opened from a prescription, its medicines head the screen
/// as one-tap searches.
class PharmacyShopScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final bool autofocus;

  /// Medicine names from a prescription being ordered.
  final List<String> prescribed;
  const PharmacyShopScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.autofocus = false,
    this.prescribed = const [],
  });

  @override
  State<PharmacyShopScreen> createState() => _PharmacyShopScreenState();
}

class _PharmacyShopScreenState extends State<PharmacyShopScreen> {
  late final _search = TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  late String? _category = widget.initialCategory;
  String? _rx; // null, 'otc', 'required'

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

  Future<void> _load() => context.read<PharmacyProvider>().loadCatalog(
    query: _search.text.trim(),
    category: _category,
    rx: _rx,
  );

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _searchFor(String name) {
    _search.text = name;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    final store = p.selectedStore;
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(
          title: widget.prescribed.isNotEmpty ? 'Order prescription' : 'Shop medicines',
          subtitle: (store?['name'] ?? '').toString(),
          actions: [
            IconButton(
              tooltip: 'Change pharmacy',
              icon: const Icon(LucideIcons.store, size: 21),
              onPressed: () async {
                await Navigator.of(context).push(AppPageRoute(builder: (_) => const NearbyPharmacyScreen()));
                if (mounted) _load();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (store?['paused'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: AppErrorBanner(
                  message: '${store?['name'] ?? 'This pharmacy'} isn’t taking orders right now. Choose another to order today.',
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _search,
                autofocus: widget.autofocus,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                cursorColor: pharmacyAccent.color,
                style: AppType.sans(fontSize: AppType.body + 1, color: AppColors.textStrong),
                decoration: InputDecoration(
                  hintText: 'Search by medicine or salt',
                  prefixIcon: const Icon(LucideIcons.search, size: 19, color: AppColors.textSecondary),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(LucideIcons.x, size: 17),
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.panel,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: pharmacyAccent.color, width: 1.5),
                  ),
                ),
              ),
            ),
            if (widget.prescribed.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From your prescription — tap to find each',
                      style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: pharmacyAccent.color),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in widget.prescribed)
                          AppFilterChip(label: m, selected: _search.text == m, onTap: () => _searchFor(m)),
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final (v, label) in const [(null, 'All'), ('otc', 'No Rx needed'), ('required', 'Rx only')]) ...[
                    AppFilterChip(
                      label: label,
                      selected: _rx == v,
                      onTap: () {
                        setState(() => _rx = v);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), color: AppColors.borderStrong),
                  const SizedBox(width: 4),
                  for (final e in kMedicineCategories.entries) ...[
                    AppFilterChip(
                      label: e.value,
                      selected: _category == e.key,
                      onTap: () {
                        setState(() => _category = _category == e.key ? null : e.key);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                color: pharmacyAccent.color,
                onRefresh: _load,
                child: p.isLoading && p.products.isEmpty
                    ? const AppListSkeleton(count: 6)
                    : p.products.isEmpty
                    ? ListView(
                        children: [
                          AppEmptyState(
                            illustration: p.error != null ? Illustrations.offline : Illustrations.notFound,
                            title: p.error != null ? 'Couldn’t load medicines' : 'Nothing matches that',
                            message: p.error ?? 'Check the spelling, try the salt name, or clear the filters.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: p.products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => AppEntrance(
                          index: i.clamp(0, 8),
                          child: ProductTile(product: p.products[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const CartBar(),
      ),
    );
  }
}
