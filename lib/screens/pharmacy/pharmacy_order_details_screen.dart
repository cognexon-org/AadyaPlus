import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_cart_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PharmacyOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const PharmacyOrderDetailsScreen({super.key, required this.orderId});
  @override
  State<PharmacyOrderDetailsScreen> createState() => _PharmacyOrderDetailsScreenState();
}

class _PharmacyOrderDetailsScreenState extends State<PharmacyOrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final order = await context.read<PharmacyProvider>().refreshOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(o?['orderNumber']?.toString() ?? 'Medicine Order')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : o == null ? const SizedBox() : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _card('Status', [
            Text(_label(o['orderStatus']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppConstants.primaryColor)),
            Text('Payment: ${_label(o['paymentStatus'])} • ${_label(o['paymentMethod'])}'),
            if (o['prescriptionRequired'] == true) Text('Prescription: ${_label(o['prescriptionStatus'])}'),
          ]),
          const SizedBox(height: 12),
          _card('Items', [
            ..._list(o['items']).map((i) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: Text((i['medicineName'] ?? 'Medicine').toString()),
              subtitle: Text('Qty ${i['quantity'] ?? 0}'),
              trailing: Text('₹${_double(i['totalAmount']).toStringAsFixed(2)}'),
            )),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)), Text('₹${_double(o['totalAmount']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
          ]),
          const SizedBox(height: 12),
          if (o['tracking'] is Map) _tracking(Map<String, dynamic>.from(o['tracking'])),
          const SizedBox(height: 12),
          _card('Order timeline', [
            ..._list(o['statusHistory']).reversed.map((h) => ListTile(
              contentPadding: EdgeInsets.zero, dense: true,
              leading: const Icon(Icons.circle, size: 12, color: AppConstants.primaryColor),
              title: Text(_label(h['status'])),
              subtitle: Text((h['note'] ?? '').toString()),
            )),
          ]),
          const SizedBox(height: 16),
          if (o['paymentMethod'] == 'online' && o['paymentStatus'] == 'pending' && o['orderStatus'] != 'cancelled')
            ElevatedButton.icon(
              onPressed: () async {
                final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentCheckoutScreen(
                  entityType: 'pharmacy_order', entityId: widget.orderId,
                  title: 'Medicine order ${(o['orderNumber'] ?? '').toString()}', expectedAmount: _double(o['totalAmount']),
                )));
                if (paid == true) _load();
              },
              icon: const Icon(Icons.lock_outline), label: const Text('Complete online payment'),
            ),
          if (['payment_pending', 'prescription_review', 'placed'].contains(o['orderStatus']))
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                  title: const Text('Cancel order?'), content: const Text('Any eligible online payment will be sent through the backend refund flow.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order'))],
                ));
                if (ok == true) { await context.read<PharmacyProvider>().cancelOrder(widget.orderId); await _load(); }
              },
              icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel order'),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<PharmacyProvider>().reorder(widget.orderId);
              if (!context.mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyCartScreen()));
            },
            icon: const Icon(Icons.replay), label: const Text('Reorder available items'),
          ),
        ]),
      ),
    );
  }

  Widget _tracking(Map<String, dynamic> t) => _card('Delivery tracking', [
    if ((t['carrier'] ?? '').toString().isNotEmpty) Text('Carrier: ${t['carrier']}'),
    if ((t['trackingNumber'] ?? '').toString().isNotEmpty) Text('Tracking #: ${t['trackingNumber']}'),
    if (t['estimatedDeliveryAt'] != null) Text('Estimated: ${t['estimatedDeliveryAt']}'),
  ]);

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 10), ...children]),
  );

  static List<Map<String, dynamic>> _list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static String _label(dynamic value) => value.toString().replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
}
