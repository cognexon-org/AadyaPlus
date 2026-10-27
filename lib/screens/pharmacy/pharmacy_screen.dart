import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/pharmacy_provider.dart';
import '../prescriptions/prescriptions_screen.dart';
import 'nearby_pharmacy_screen.dart';
import 'pharmacy_cart_screen.dart';
import 'pharmacy_order_details_screen.dart';
import 'pharmacy_orders_screen.dart';
import 'pharmacy_shop_screen.dart';
import 'pharmacy_widgets.dart';

/// The Medicines tab: which pharmacy delivers to you, search, shop by
/// form, order from a prescription, and orders on their way.
class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key});

  static const _done = ['delivered', 'cancelled', 'returned'];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    final store = p.selectedStore;
    final active = p.orders.where((o) => !_done.contains(o['orderStatus'])).toList();
    void push(Widget w) => Navigator.of(context).push(AppPageRoute(builder: (_) => w));
    void shop({String? query, String? category, bool focus = false}) => push(
      store == null
          ? const NearbyPharmacyScreen()
          : PharmacyShopScreen(initialQuery: query, initialCategory: category, autofocus: focus),
    );
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(
          title: 'Medicines',
          showBack: Navigator.of(context).canPop(),
          actions: [_CartButton(count: p.cartCount, onTap: () => push(const PharmacyCartScreen()))],
        ),
        body: RefreshIndicator(
          color: pharmacyAccent.color,
          onRefresh: p.bootstrap,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: AppEntrance(child: _StoreCard(store: store, loading: p.isLoading && store == null, onChange: () => push(const NearbyPharmacyScreen()))),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppEntrance(
                  index: 1,
                  child: AppPressable(
                    onTap: () => shop(focus: true),
                    scale: 0.99,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.search, size: 19, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text('Search medicines', style: AppType.sans(fontSize: AppType.body + 0.5, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppEntrance(
                  index: 2,
                  child: AppPressable(
                    onTap: () => push(const PrescriptionsScreen()),
                    scale: 0.985,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: BoxDecoration(
                        color: pharmacyAccent.veryLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: pharmacyAccent.light),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order from a prescription',
                                  style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pick one your doctor issued on Aadya Plus, or upload a photo at checkout.',
                                  style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const AppIllustration(Illustrations.prescription, height: 72),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 26),
                AppSectionHeader(title: 'On the way', action: 'All orders', onAction: () => push(const PharmacyOrdersScreen())),
                for (final o in active.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: OrderCard(order: o, onTap: () => push(PharmacyOrderDetailsScreen(orderId: idOf(o)))),
                  ),
              ],
              const SizedBox(height: 26),
              const AppSectionHeader(title: 'Shop by form'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, box) {
                    const gap = 10.0;
                    final w = (box.maxWidth - gap * 3) / 4;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final e in kMedicineCategories.entries.where((e) => e.key != 'other'))
                          SizedBox(
                            width: w,
                            child: AppPressable(
                              onTap: () => shop(category: e.key),
                              semanticLabel: e.value,
                              child: Column(
                                children: [
                                  Container(
                                    width: w,
                                    height: w * 0.78,
                                    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16)),
                                    child: Icon(medicineCategoryIcon(e.key), size: 24, color: pharmacyAccent.color),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(e.value, style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  onTap: () => push(const PharmacyOrdersScreen()),
                  child: Row(
                    children: [
                      Icon(LucideIcons.receipt, size: 20, color: pharmacyAccent.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Order history',
                          style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                        ),
                      ),
                      Text('${p.orders.length}', style: AppType.sans(fontSize: AppType.body, color: AppColors.textSecondary)),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const CartBar(),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: count > 0 ? 'Cart, $count items' : 'Cart',
    onPressed: onTap,
    icon: Badge(
      isLabelVisible: count > 0,
      backgroundColor: pharmacyAccent.color,
      label: Text('$count'),
      child: const Icon(LucideIcons.shoppingBag, size: 22),
    ),
  );
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic>? store;
  final bool loading;
  final VoidCallback onChange;
  const _StoreCard({required this.store, required this.loading, required this.onChange});

  @override
  Widget build(BuildContext context) {
    if (loading) return const AppShimmer(child: AppSkeletonBlock(width: double.infinity, height: 72, radius: 18));
    final s = store;
    final eco = mapOf(s?['ecommerce']);
    final eta = (eco['estimatedDeliveryMinutes'] as num?)?.toInt();
    final fee = asDouble(eco['deliveryFee']);
    final free = asDouble(eco['freeDeliveryThreshold']);
    final paused = s?['paused'] == true;
    final line = s == null
        ? 'Choose a pharmacy that delivers to you'
        : paused
        ? 'Not taking orders right now'
        : [
            if (eta != null) eta >= 60 ? 'Delivery in ~${(eta / 60).round()} hr' : 'Delivery in ~$eta min',
            if (fee <= 0) 'Free delivery' else if (free > 0) 'Free over ${appRupees(free)}' else '${appRupees(fee)} delivery',
          ].join(' · ');
    return AppPressable(
      onTap: onChange,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(14)),
              child: Icon(LucideIcons.store, size: 21, color: pharmacyAccent.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s == null ? 'No pharmacy selected' : 'Delivering from',
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                  Text(
                    (s?['name'] ?? 'Choose a pharmacy').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                  ),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: paused ? AppColors.warning : pharmacyAccent.color),
                  ),
                ],
              ),
            ),
            Text('Change', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w700, color: pharmacyAccent.color)),
          ],
        ),
      ),
    );
  }
}
