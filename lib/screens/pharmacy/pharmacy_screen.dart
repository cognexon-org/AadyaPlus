import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/pharmacy/nearby_pharmacy_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_cart_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_orders_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_shop_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    final store = p.selectedStore;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Aadya Pharmacy', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async { await p.loadStores(); await p.loadCart(); await p.loadOrders(); },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppConstants.primaryColor, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Medicines from a real pharmacy branch', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(store == null ? 'Choose a serviceable pharmacy to see live stock and prices.' : 'Selected: ${store['name'] ?? 'Pharmacy'}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyPharmacyScreen())),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(store == null ? 'Choose pharmacy' : 'Change pharmacy'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _ActionCard(icon: Icons.medication_outlined, title: 'Shop', subtitle: 'Live catalog', onTap: store == null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyPharmacyScreen())) : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyShopScreen())))),
              const SizedBox(width: 10),
              Expanded(child: _ActionCard(icon: Icons.shopping_cart_outlined, title: 'Cart', subtitle: '${p.cartCount} items', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyCartScreen())))),
            ]),
            const SizedBox(height: 10),
            _ActionCard(icon: Icons.local_shipping_outlined, title: 'My medicine orders', subtitle: 'Track payment, prescription review, packing and delivery', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen()))),
            if (p.orders.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Recent orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...p.orders.take(3).map((o) => Card(child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: AppConstants.primaryColor),
                title: Text((o['orderNumber'] ?? 'Order').toString()),
                subtitle: Text((o['orderStatus'] ?? '').toString().replaceAll('_', ' ')),
                trailing: Text('₹${_double(o['totalAmount']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen())),
              ))),
            ],
          ],
        ),
      ),
    );
  }

  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        CircleAvatar(backgroundColor: AppConstants.primaryColor.withOpacity(.1), child: Icon(icon, color: AppConstants.primaryColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
        const Icon(Icons.chevron_right),
      ])),
    ),
  );
}
