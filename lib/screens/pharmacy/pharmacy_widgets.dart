import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/pharmacy_provider.dart';
import 'pharmacy_cart_screen.dart';

// Pieces shared by the medicine screens: product rows, the quantity
// stepper, the floating cart bar, the bill and the order card.

ModuleAccent get pharmacyAccent => ModuleAccent.pharmacy;

/// The price a patient pays for one unit, and the listed price it's cut from.
(double, double) productPrices(Map<String, dynamic> p) {
  final finalPrice = asDouble(p['finalUnitPrice'] ?? p['unitPrice'] ?? p['sellingPrice']);
  final listed = asDouble(p['sellingPrice']);
  return (finalPrice, listed > finalPrice ? listed : finalPrice);
}

String productSubtitle(Map<String, dynamic> p) => [
  p['strength'],
  if ((p['dosageForm'] ?? '').toString().isNotEmpty) sentenceCase(p['dosageForm'].toString()),
  p['manufacturer'] ?? p['brandName'],
].where((e) => e != null && e.toString().trim().isNotEmpty).join(' · ');

/// How many of [medicineId] are in the cart.
int cartQuantity(PharmacyProvider p, String medicineId) {
  for (final line in p.cartItems) {
    if ((line['medicineId'] ?? idOf(line['medicine'])).toString() == medicineId) {
      return (line['quantity'] as num?)?.toInt() ?? 0;
    }
  }
  return 0;
}

/// A medicine in the shop: name, strength and maker, price with any
/// discount, an Rx tag when a prescription is needed, and add / − n +.
class ProductTile extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductTile({super.key, required this.product});

  @override
  State<ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<ProductTile> {
  bool _busy = false;

  Future<void> _set(int quantity) async {
    final p = context.read<PharmacyProvider>();
    final id = idOf(widget.product);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      final current = cartQuantity(p, id);
      if (current == 0) {
        await p.addToCart(widget.product, quantity: quantity);
      } else if (quantity <= 0) {
        await p.removeFromCart(id);
      } else {
        await p.updateCartQuantity(id, quantity);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final provider = context.watch<PharmacyProvider>();
    final inCart = cartQuantity(provider, idOf(p));
    final (price, listed) = productPrices(p);
    final off = listed > price ? ((listed - price) / listed * 100).round() : 0;
    final inStock = p['inStock'] != false && ((p['quantity'] as num?) ?? 1) > 0;
    final rx = p['prescriptionRequired'] == true;
    final maxQty = ((p['quantity'] as num?)?.toInt() ?? 20).clamp(1, 20);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(14)),
            child: Icon(medicineCategoryIcon(p['category']?.toString()), size: 22, color: pharmacyAccent.color),
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
                        (p['medicineName'] ?? 'Medicine').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                      ),
                    ),
                    if (rx) ...[const SizedBox(width: 6), const RxTag()],
                  ],
                ),
                if (productSubtitle(p).isNotEmpty)
                  Text(
                    productSubtitle(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      appRupees(price),
                      style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                    ),
                    if (off > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        appRupees(listed),
                        style: AppType.sans(
                          fontSize: AppType.caption,
                          color: AppColors.textTertiary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$off% off',
                        style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: pharmacyAccent.color),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!inStock)
            Text('Out of stock', style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: AppColors.textTertiary))
          else if (inCart == 0)
            AppPressable(
              onTap: _busy ? null : () => _set(1),
              semanticLabel: 'Add ${p['medicineName']}',
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pharmacyAccent.veryLight,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: pharmacyAccent.light),
                ),
                child: _busy
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: pharmacyAccent.color))
                    : Text('Add', style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: pharmacyAccent.color)),
              ),
            )
          else
            QtyStepper(
              value: inCart,
              max: maxQty,
              busy: _busy,
              onChanged: _set,
            ),
        ],
      ),
    );
  }
}

class RxTag extends StatelessWidget {
  const RxTag({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Needs a prescription',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(5)),
      child: Text('Rx', style: AppType.sans(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: AppColors.warning)),
    ),
  );
}

/// − n + in the pharmacy green.
class QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final bool busy;
  final ValueChanged<int> onChanged;
  const QtyStepper({super.key, required this.value, required this.onChanged, this.max = 20, this.busy = false});

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(color: pharmacyAccent.color, borderRadius: BorderRadius.circular(11)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: value == 1 ? LucideIcons.trash2 : LucideIcons.minus, onTap: busy ? null : () => onChanged(value - 1), label: 'Remove one'),
        SizedBox(
          width: 26,
          child: Center(
            child: busy
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
                : Text('$value', style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        _StepButton(icon: LucideIcons.plus, onTap: busy || value >= max ? null : () => onChanged(value + 1), label: 'Add one'),
      ],
    ),
  );
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  const _StepButton({required this.icon, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 18,
      child: SizedBox(
        width: 32,
        height: 36,
        child: Icon(icon, size: 15, color: onTap == null ? Colors.white54 : Colors.white),
      ),
    ),
  );
}

/// The cart, floating over a shop screen while it has anything in it.
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      transitionBuilder: (c, a) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: AppMotion.enter)),
        child: c,
      ),
      child: p.cartCount == 0
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppPressable(
                  onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const PharmacyCartScreen())),
                  scale: 0.98,
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: pharmacyAccent.color,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.shadowElevated,
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.shoppingBag, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.cartCount} item${p.cartCount == 1 ? '' : 's'}',
                                style: AppType.sans(fontSize: AppType.caption, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                              Text(
                                appRupees(p.cartSubtotal),
                                style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Text('View cart', style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: Colors.white)),
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

/// Bill lines: label on the left, amount on the right; [strong] for the total.
class BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;
  const BillLine(this.label, this.value, {super.key, this.strong = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.sans(
              fontSize: strong ? AppType.title : AppType.body,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              color: strong ? AppColors.textStrong : AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppType.sans(
            fontSize: strong ? AppType.title + 1 : AppType.body,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textStrong,
          ),
        ),
      ],
    ),
  );
}

/// A medicine order in a list.
class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = mapOf(order['storeId']);
    final items = mapsOf(order['items']);
    final status = PatientStatus.of(order['orderStatus']?.toString());
    final created = DateTime.tryParse('${order['createdAt']}')?.toLocal();
    final names = items.map((i) => (i['medicineName'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
    return AppPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(status.icon, size: 19, color: pharmacyAccent.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (store['name'] ?? 'Pharmacy').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                      ),
                      Text(
                        [
                          (order['orderNumber'] ?? '').toString(),
                          if (created != null) DateFormat('d MMM, h:mm a').format(created),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  appRupees(order['totalAmount']),
                  style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                ),
              ],
            ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                names.length > 2 ? '${names.take(2).join(', ')} +${names.length - 2} more' : names.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                status.pill(),
                const Spacer(),
                if (order['paymentStatus'] == 'pending' && order['paymentMethod'] == 'online' && order['orderStatus'] == 'payment_pending')
                  Text('Pay to confirm', style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: AppColors.warning)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
