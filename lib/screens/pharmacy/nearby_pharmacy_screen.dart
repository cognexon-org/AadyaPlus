import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/location_provider.dart';
import '../../providers/pharmacy_provider.dart';
import 'pharmacy_widgets.dart';

/// Choose the pharmacy that delivers: by name, and checked against the
/// delivery pincode so a store that can't reach you says so up front.
class NearbyPharmacyScreen extends StatefulWidget {
  const NearbyPharmacyScreen({super.key});

  @override
  State<NearbyPharmacyScreen> createState() => _NearbyPharmacyScreenState();
}

class _NearbyPharmacyScreenState extends State<NearbyPharmacyScreen> {
  final _search = TextEditingController();
  late final _pincode = TextEditingController(text: context.read<LocationProvider>().pincode ?? '');
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<PharmacyProvider>().loadStores(
    pincode: _pincode.text.trim().length == 6 ? _pincode.text.trim() : null,
    query: _search.text.trim(),
  );

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refresh);
  }

  Future<void> _choose(Map<String, dynamic> store) async {
    final p = context.read<PharmacyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (p.cartCount > 0 && idOf(p.selectedStore) != idOf(store)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Switch pharmacy?'),
          content: Text('Your cart has ${p.cartCount} item${p.cartCount == 1 ? '' : 's'} from ${p.selectedStore?['name'] ?? 'another pharmacy'}. Switching empties it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep cart')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Switch')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await p.clearCart();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
        return;
      }
    }
    HapticFeedback.selectionClick();
    await p.selectStore(store);
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppTopBar(title: 'Choose a pharmacy'),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchField(controller: _search, hint: 'Pharmacy name', onChanged: _changed),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 118,
                    child: TextField(
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      onChanged: (v) {
                        if (v.length == 6 || v.isEmpty) _changed(v);
                      },
                      style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Pincode',
                        prefixIcon: const Icon(LucideIcons.mapPin, size: 17),
                        prefixIconConstraints: const BoxConstraints(minWidth: 38),
                        filled: true,
                        fillColor: AppColors.panel,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: pharmacyAccent.color,
                onRefresh: _refresh,
                child: p.isLoading && p.stores.isEmpty
                    ? const AppListSkeleton(count: 4)
                    : p.stores.isEmpty
                    ? ListView(
                        children: [
                          AppEmptyState(
                            illustration: p.error != null ? Illustrations.offline : Illustrations.pharmacy,
                            title: p.error != null ? 'Couldn’t load pharmacies' : 'No pharmacy delivers here yet',
                            message: p.error ?? 'Try another pincode or clear the search.',
                            actionLabel: 'Try again',
                            onAction: _refresh,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: p.stores.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = p.stores[i];
                          return AppEntrance(
                            index: i.clamp(0, 6),
                            child: _StoreTile(
                              store: s,
                              selected: idOf(s) == idOf(p.selectedStore),
                              onTap: () => _choose(s),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final Map<String, dynamic> store;
  final bool selected;
  final VoidCallback onTap;
  const _StoreTile({required this.store, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final address = mapOf(store['address']);
    final eco = mapOf(store['ecommerce']);
    final eta = (eco['estimatedDeliveryMinutes'] as num?)?.toInt();
    final fee = asDouble(eco['deliveryFee']);
    final minOrder = asDouble(eco['minOrderAmount']);
    final paused = store['paused'] == true;
    final serviceable = store['serviceable'] != false;
    final place = [address['line1'] ?? address['address'], address['city'], address['pincode']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');
    return AppPressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? pharmacyAccent.veryLight : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? pharmacyAccent.color : AppColors.borderStrong, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: selected ? Colors.white : pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(13)),
                  child: Icon(LucideIcons.store, size: 20, color: pharmacyAccent.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (store['name'] ?? 'Pharmacy').toString(),
                        style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                      ),
                      if (place.isNotEmpty)
                        Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (selected) Icon(LucideIcons.circleCheck, color: pharmacyAccent.color, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (paused)
                  const AppStatusPill(text: 'Paused', icon: LucideIcons.pause, color: AppColors.warning, background: AppColors.warningBg)
                else if (!serviceable)
                  const AppStatusPill(text: 'Doesn’t deliver to this pincode', icon: LucideIcons.mapPinOff, color: AppColors.error, background: AppColors.errorBg)
                else ...[
                  if (eta != null)
                    AppStatusPill(
                      text: eta >= 60 ? '~${(eta / 60).round()} hr' : '~$eta min',
                      icon: LucideIcons.bike,
                      color: pharmacyAccent.color,
                      background: pharmacyAccent.veryLight,
                    ),
                  AppStatusPill(
                    text: fee <= 0 ? 'Free delivery' : '${appRupees(fee)} delivery',
                    icon: LucideIcons.truck,
                    color: AppColors.textPrimary,
                    background: AppColors.panel,
                  ),
                  if (minOrder > 0)
                    AppStatusPill(text: 'Min ${appRupees(minOrder)}', color: AppColors.textPrimary, background: AppColors.panel),
                  if (eco['codEnabled'] != false)
                    const AppStatusPill(text: 'Cash on delivery', color: AppColors.textPrimary, background: AppColors.panel),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
