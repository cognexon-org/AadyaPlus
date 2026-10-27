import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/pharmacy_provider.dart';
import 'epharmacy_checkout_screen.dart';
import 'pharmacy_shop_screen.dart';
import 'pharmacy_widgets.dart';

/// The cart: lines with quantity, anything that ran short, the item total
/// and what the store asks (minimum order, delivery), then checkout.
class PharmacyCartScreen extends StatefulWidget {
  const PharmacyCartScreen({super.key});

  @override
  State<PharmacyCartScreen> createState() => _PharmacyCartScreenState();
}

class _PharmacyCartScreenState extends State<PharmacyCartScreen> {
  String? _busyLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PharmacyProvider>().loadCart());
  }

  Future<void> _set(String id, int qty) async {
    final p = context.read<PharmacyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyLine = id);
    try {
      qty <= 0 ? await p.removeFromCart(id) : await p.updateCartQuantity(id, qty);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busyLine = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    final store = p.selectedStore;
    final eco = mapOf(store?['ecommerce']);
    final minOrder = asDouble(eco['minOrderAmount']);
    final fee = asDouble(eco['deliveryFee']);
    final freeOver = asDouble(eco['freeDeliveryThreshold']);
    final subtotal = p.cartSubtotal;
    final short = p.cartItems.where((l) => l['available'] == false).toList();
    final belowMin = minOrder > 0 && subtotal < minOrder;
    final needsRx = p.cartItems.any((l) => mapOf(l['medicine'])['prescriptionRequired'] == true);
    final canCheckout = p.cartItems.isNotEmpty && short.isEmpty && !belowMin && store?['paused'] != true;
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(
          title: 'Cart',
          subtitle: p.cartItems.isEmpty ? null : (store?['name'] ?? '').toString(),
          actions: [
            if (p.cartItems.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Empty your cart?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Empty')),
                      ],
                    ),
                  );
                  if (ok == true) await p.clearCart();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Text('Clear'),
              ),
          ],
        ),
        body: p.cartItems.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: AppEmptyState(
                    illustration: Illustrations.emptyCart,
                    title: 'Your cart is empty',
                    message: 'Add medicines from your pharmacy and they’ll show up here.',
                    actionLabel: 'Shop medicines',
                    onAction: () => Navigator.of(context).pushReplacement(AppPageRoute(builder: (_) => const PharmacyShopScreen())),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (short.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppErrorBanner(message: 'The pharmacy has fewer of ${short.length == 1 ? 'one item' : '${short.length} items'} than you asked for. Lower the quantity to continue.'),
                    ),
                  if (needsRx)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.fileText, size: 18, color: AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Some items need a prescription. You’ll attach it at checkout.',
                              style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final line in p.cartItems) ...[
                    _CartLine(
                      line: line,
                      busy: _busyLine == (line['medicineId'] ?? '').toString(),
                      onChanged: (q) => _set((line['medicineId'] ?? '').toString(), q),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const PharmacyShopScreen())),
                    icon: const Icon(LucideIcons.plus, size: 17),
                    label: const Text('Add more items'),
                    style: TextButton.styleFrom(foregroundColor: pharmacyAccent.color),
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        BillLine('Items (${p.cartCount})', appRupees(subtotal)),
                        BillLine(
                          'Delivery',
                          fee <= 0 || (freeOver > 0 && subtotal >= freeOver) ? 'Free' : appRupees(fee),
                          valueColor: fee <= 0 || (freeOver > 0 && subtotal >= freeOver) ? pharmacyAccent.color : null,
                        ),
                        const Divider(height: 18),
                        Text(
                          'Taxes, coupons and the final total are worked out at checkout.',
                          style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (freeOver > 0 && fee > 0 && subtotal < freeOver)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Add ${appRupees(freeOver - subtotal)} more for free delivery',
                        textAlign: TextAlign.center,
                        style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: pharmacyAccent.color),
                      ),
                    ),
                ],
              ),
        bottomNavigationBar: p.cartItems.isEmpty
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (belowMin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Minimum order is ${appRupees(minOrder)} — add ${appRupees(minOrder - subtotal)} more',
                            style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.warning),
                          ),
                        ),
                      AppButton(
                        label: 'Checkout · ${appRupees(subtotal)}',
                        icon: LucideIcons.arrowRight,
                        onPressed: canCheckout
                            ? () => Navigator.of(context).push(AppPageRoute(builder: (_) => const EPharmacyCheckoutScreen()))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  final Map<String, dynamic> line;
  final bool busy;
  final ValueChanged<int> onChanged;
  const _CartLine({required this.line, required this.busy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final m = mapOf(line['medicine']);
    final qty = (line['quantity'] as num?)?.toInt() ?? 1;
    final short = line['available'] == false;
    final stock = (m['quantity'] as num?)?.toInt() ?? 20;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: short ? AppColors.error.withValues(alpha: 0.4) : AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(13)),
            child: Icon(medicineCategoryIcon(m['category']?.toString()), size: 20, color: pharmacyAccent.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (m['medicineName'] ?? line['medicineName'] ?? 'Medicine').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                      ),
                    ),
                    if (m['prescriptionRequired'] == true) ...[const SizedBox(width: 6), const RxTag()],
                  ],
                ),
                Text(
                  short ? 'Only $stock available' : productSubtitle(m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    fontWeight: short ? FontWeight.w700 : FontWeight.w400,
                    color: short ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appRupees(line['totalAmount']),
                  style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                ),
              ],
            ),
          ),
          QtyStepper(value: qty, max: stock.clamp(1, 20), busy: busy, onChanged: onChanged),
        ],
      ),
    );
  }
}
