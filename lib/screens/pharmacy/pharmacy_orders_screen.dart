import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_cart_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_order_details_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PharmacyOrdersScreen extends StatefulWidget {
  const PharmacyOrdersScreen({super.key});
  @override
  State<PharmacyOrdersScreen> createState() => _PharmacyOrdersScreenState();
}

class _PharmacyOrdersScreenState extends State<PharmacyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PharmacyProvider>().loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Medicine Orders')),
      body: RefreshIndicator(
        onRefresh: p.loadOrders,
        child: p.orders.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No medicine orders yet.'))])
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: p.orders.length,
                itemBuilder: (context, index) {
                  final o = p.orders[index];
                  final store = o['storeId'] is Map ? Map<String, dynamic>.from(o['storeId']) : <String, dynamic>{};
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      title: Text((o['orderNumber'] ?? 'Order').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${store['name'] ?? 'Pharmacy'}\n${_label(o['orderStatus'])} • ${_label(o['paymentStatus'])}'),
                      isThreeLine: true,
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₹${_double(o['totalAmount']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppConstants.primaryColor)),
                        const Icon(Icons.chevron_right),
                      ]),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PharmacyOrderDetailsScreen(orderId: _id(o)))),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: p.cartCount > 0 ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyCartScreen())),
        icon: const Icon(Icons.shopping_cart_outlined),
        label: Text('Cart (${p.cartCount})'),
      ) : null,
    );
  }

  static String _id(Map<String, dynamic> m) => (m['_id'] ?? m['id'] ?? '').toString();
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static String _label(dynamic value) => value.toString().replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
}
