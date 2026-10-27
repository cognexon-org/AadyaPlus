import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart' show MethodSwitch;
import '../../providers/pharmacy_provider.dart';
import 'pharmacy_order_details_screen.dart';
import 'pharmacy_shop_screen.dart';
import 'pharmacy_widgets.dart';

/// Every medicine order: the ones still moving, and the history.
class PharmacyOrdersScreen extends StatefulWidget {
  const PharmacyOrdersScreen({super.key});

  @override
  State<PharmacyOrdersScreen> createState() => _PharmacyOrdersScreenState();
}

class _PharmacyOrdersScreenState extends State<PharmacyOrdersScreen> {
  int _tab = 0;
  static const _done = ['delivered', 'cancelled', 'returned'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PharmacyProvider>().loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    final active = p.orders.where((o) => !_done.contains(o['orderStatus'])).toList();
    final past = p.orders.where((o) => _done.contains(o['orderStatus'])).toList();
    final list = _tab == 0 ? active : past;
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppTopBar(title: 'Medicine orders'),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: MethodSwitch(
                labels: ['Active${active.isEmpty ? '' : ' · ${active.length}'}', 'Past'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: pharmacyAccent.color,
                onRefresh: p.loadOrders,
                child: list.isEmpty
                    ? ListView(
                        children: [
                          AppEmptyState(
                            illustration: Illustrations.onTheWay,
                            title: _tab == 0 ? 'No orders on the way' : 'No past orders',
                            message: _tab == 0 ? 'Order medicines and follow them here until they reach you.' : null,
                            actionLabel: _tab == 0 ? 'Shop medicines' : null,
                            onAction: _tab == 0
                                ? () => Navigator.of(context).push(AppPageRoute(builder: (_) => const PharmacyShopScreen()))
                                : null,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => AppEntrance(
                          index: i.clamp(0, 6),
                          child: OrderCard(
                            order: list[i],
                            onTap: () => Navigator.of(context).push(
                              AppPageRoute(builder: (_) => PharmacyOrderDetailsScreen(orderId: idOf(list[i]))),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
