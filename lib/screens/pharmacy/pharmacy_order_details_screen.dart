import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/pharmacy_provider.dart';
import '../payments/payment_checkout_screen.dart';
import 'pharmacy_cart_screen.dart';
import 'pharmacy_widgets.dart';

/// A medicine order: where it is on its way, who's bringing it, what's in
/// it, the bill, and what can still be done (pay, cancel, order again).
/// Refreshes itself while the order is moving.
class PharmacyOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const PharmacyOrderDetailsScreen({super.key, required this.orderId});

  @override
  State<PharmacyOrderDetailsScreen> createState() => _PharmacyOrderDetailsScreenState();
}

class _PharmacyOrderDetailsScreenState extends State<PharmacyOrderDetailsScreen> {
  Map<String, dynamic>? _order;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  static const _cancellable = ['payment_pending', 'prescription_review', 'placed'];
  static const _final = ['delivered', 'cancelled', 'returned'];
  static const _steps = [
    ('placed', 'Placed', LucideIcons.receipt),
    ('confirmed', 'Confirmed', LucideIcons.circleCheck),
    ('packing', 'Packed', LucideIcons.package),
    ('out_for_delivery', 'On the way', LucideIcons.bike),
    ('delivered', 'Delivered', LucideIcons.packageCheck),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_order != null && !_final.contains(_order!['orderStatus'])) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _error = null);
    try {
      final o = await context.read<PharmacyProvider>().refreshOrder(widget.orderId);
      if (mounted) setState(() => _order = o);
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    }
  }

  int _stepIndex(String status) => switch (status) {
    'payment_pending' || 'prescription_review' || 'placed' => 0,
    'confirmed' => 1,
    'packing' || 'ready_to_ship' => 2,
    'shipped' || 'out_for_delivery' => 3,
    'delivered' => 4,
    _ => -1,
  };

  (String, String?) _headline(Map<String, dynamic> o) {
    final status = (o['orderStatus'] ?? '').toString();
    final eta = DateTime.tryParse('${mapOf(o['tracking'])['estimatedDeliveryAt']}')?.toLocal();
    final etaText = eta == null ? null : 'Expected by ${DateFormat('h:mm a, d MMM').format(eta)}';
    return switch (status) {
      'payment_pending' => ('Waiting for payment', 'Pay within 30 minutes of ordering, or the order is cancelled.'),
      'prescription_review' => ('Pharmacist is checking your prescription', 'Usually takes a few minutes.'),
      'placed' => ('Order placed', 'The pharmacy will confirm it shortly.'),
      'confirmed' => ('Confirmed by the pharmacy', etaText),
      'packing' || 'ready_to_ship' => ('Being packed', etaText),
      'shipped' || 'out_for_delivery' => ('On the way to you', etaText),
      'delivered' => (
        'Delivered',
        DateTime.tryParse('${mapOf(o['tracking'])['deliveredAt']}') != null
            ? DateFormat('d MMM, h:mm a').format(DateTime.parse('${mapOf(o['tracking'])['deliveredAt']}').toLocal())
            : null,
      ),
      'cancel_requested' => ('Cancellation requested', 'We’ll update you once the pharmacy responds.'),
      'cancelled' => (
        'Cancelled',
        o['rejectionReason'] != null
            ? 'The pharmacy declined: ${sentenceCase(o['rejectionReason'].toString())}'
            : (o['cancellationReason'] ?? '').toString(),
      ),
      'returned' => ('Returned', null),
      _ => (PatientStatus.of(status).label, null),
    };
  }

  Future<void> _pay(Map<String, dynamic> o) async {
    final paid = await Navigator.of(context).push<bool>(AppPageRoute(
      builder: (_) => PaymentCheckoutScreen(
        entityType: 'pharmacy_order',
        entityId: idOf(o),
        title: 'Medicine order ${o['orderNumber'] ?? ''}',
        expectedAmount: asDouble(o['totalAmount']),
      ),
    ));
    if (paid == true) _load();
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('If you’ve paid, the refund goes back to how you paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep order')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PharmacyProvider>().cancelOrder(widget.orderId);
      await _load();
      messenger.showSnackBar(const SnackBar(content: Text('Order cancelled')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder() async {
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PharmacyProvider>().reorder(widget.orderId);
      nav.push(AppPageRoute(builder: (_) => const PharmacyCartScreen()));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: 'Order', subtitle: o == null ? null : (o['orderNumber'] ?? '').toString()),
        body: o == null
            ? (_error != null
                  ? Center(
                      child: AppEmptyState(
                        illustration: Illustrations.offline,
                        title: 'Couldn’t load this order',
                        message: _error,
                        actionLabel: 'Try again',
                        onAction: _load,
                      ),
                    )
                  : const AppDetailSkeleton())
            : RefreshIndicator(color: pharmacyAccent.color, onRefresh: _load, child: _body(o)),
        bottomNavigationBar: o == null ? null : _bottom(o),
      ),
    );
  }

  Widget? _bottom(Map<String, dynamic> o) {
    final status = (o['orderStatus'] ?? '').toString();
    final payDue = status == 'payment_pending' && o['paymentStatus'] == 'pending';
    if (!payDue && !['delivered', 'cancelled', 'returned'].contains(status)) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: payDue
            ? AppButton(label: 'Pay ${appRupees(o['totalAmount'])}', icon: LucideIcons.lock, loading: _busy, onPressed: () => _pay(o))
            : AppButton(label: 'Order again', icon: LucideIcons.rotateCw, loading: _busy, onPressed: _reorder),
      ),
    );
  }

  Widget _body(Map<String, dynamic> o) {
    final status = (o['orderStatus'] ?? '').toString();
    final (title, line) = _headline(o);
    final pill = PatientStatus.of(status);
    final step = _stepIndex(status);
    final items = mapsOf(o['items']);
    final delivery = mapOf(o['delivery']);
    final address = mapOf(o['deliveryAddress']);
    final store = mapOf(o['storeId']);
    final itemsTotal = items.fold<double>(0, (s, i) => s + asDouble(i['totalAmount']));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        AppEntrance(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: pill.background, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(pill.icon, size: 22, color: pill.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: pill.color)),
                    ),
                  ],
                ),
                if (line != null && line.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(line, style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary)),
                ],
                if (step >= 0) ...[const SizedBox(height: 16), _Progress(step: step)],
              ],
            ),
          ),
        ),
        if ((status == 'out_for_delivery' || status == 'shipped') && (delivery['driverName'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                AppAvatar(name: delivery['driverName'].toString(), size: 44, color: pharmacyAccent.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(delivery['driverName'].toString(), style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                      Text(
                        ['Delivery partner', if ((delivery['vehicleNumber'] ?? '').toString().isNotEmpty) delivery['vehicleNumber']].join(' · '),
                        style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if ((delivery['driverPhone'] ?? '').toString().isNotEmpty)
                  IconButton.filled(
                    tooltip: 'Call',
                    style: IconButton.styleFrom(backgroundColor: pharmacyAccent.color),
                    onPressed: () => launchUrl(Uri.parse('tel:${delivery['driverPhone']}')),
                    icon: const Icon(LucideIcons.phone, size: 18),
                  ),
              ],
            ),
          ),
        ],
        if (o['partiallyFulfilled'] == true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
            child: Text(
              (o['fulfilmentNote'] ?? 'The pharmacy could send only part of this order. The bill has been adjusted.').toString(),
              style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Title('${items.length} item${items.length == 1 ? '' : 's'} from ${store['name'] ?? 'the pharmacy'}'),
        AppCard(
          child: Column(
            children: [
              for (final (i, it) in items.indexed) ...[
                if (i > 0) const Divider(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((it['medicineName'] ?? 'Medicine').toString(), style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                          Text(
                            [
                              'Qty ${it['quantity']}',
                              if ((it['orderedQuantity'] as num?) != null && (it['orderedQuantity'] as num) > (it['quantity'] as num? ?? 0))
                                'of ${it['orderedQuantity']} ordered',
                            ].join(' '),
                            style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(appRupees(it['totalAmount']), style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Title('Bill'),
        AppCard(
          child: Column(
            children: [
              BillLine('Items', appRupees(itemsTotal)),
              if (asDouble(o['couponDiscount']) > 0)
                BillLine('Coupon${(o['couponCode'] ?? '').toString().isNotEmpty ? ' (${o['couponCode']})' : ''}', '−${appRupees(o['couponDiscount'])}', valueColor: pharmacyAccent.color),
              BillLine('Delivery', asDouble(o['deliveryFee']) > 0 ? appRupees(o['deliveryFee']) : 'Free'),
              const Divider(height: 18),
              BillLine('Total', appRupees(o['totalAmount']), strong: true),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    o['paymentMethod'] == 'cod' ? 'Cash on delivery' : 'Paid online',
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  PatientStatus.of(o['paymentStatus'] == 'pending' ? (o['paymentMethod'] == 'cod' ? 'pending' : 'payment_pending') : o['paymentStatus']?.toString()).pill(icon: false),
                ],
              ),
            ],
          ),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _Title('Delivering to'),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.mapPin, size: 18, color: pharmacyAccent.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      '${address['contactName'] ?? ''}${(address['phone'] ?? '').toString().isNotEmpty ? ' · ${address['phone']}' : ''}',
                      [address['line1'], address['line2'], address['landmark'], address['city'], address['pincode']]
                          .where((e) => e != null && e.toString().trim().isNotEmpty)
                          .join(', '),
                    ].where((e) => e.isNotEmpty).join('\n'),
                    style: AppType.sans(fontSize: AppType.body, height: 1.45, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (mapsOf(o['statusHistory']).isNotEmpty) ...[
          const SizedBox(height: 20),
          const _Title('Activity'),
          for (final h in mapsOf(o['statusHistory']).reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: pharmacyAccent.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(PatientStatus.of(h['status']?.toString()).label, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w600, color: AppColors.textStrong)),
                        if ((h['note'] ?? '').toString().isNotEmpty)
                          Text(h['note'].toString(), style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (DateTime.tryParse('${h['at']}') != null)
                    Text(
                      DateFormat('d MMM, h:mm a').format(DateTime.parse('${h['at']}').toLocal()),
                      style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
        ],
        if (_cancellable.contains(status)) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _cancel,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Cancel order'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
  );
}

/// Placed → Confirmed → Packed → On the way → Delivered, filled up to now.
class _Progress extends StatelessWidget {
  final int step;
  const _Progress({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = _PharmacyOrderDetailsScreenState._steps;
    final accent = pharmacyAccent.color;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              AnimatedContainer(
                duration: AppMotion.medium,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: i <= step ? accent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: i <= step ? accent : AppColors.borderStrong, width: 1.5),
                ),
                child: Icon(steps[i].$3, size: 14, color: i <= step ? Colors.white : AppColors.textTertiary),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: i < step ? 1 : 0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: AppColors.borderStrong, color: accent),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: 60,
                child: Text(
                  steps[i].$2,
                  textAlign: i == 0 ? TextAlign.left : i == steps.length - 1 ? TextAlign.right : TextAlign.center,
                  style: AppType.sans(
                    fontSize: AppType.micro,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                    color: i <= step ? AppColors.textStrong : AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
