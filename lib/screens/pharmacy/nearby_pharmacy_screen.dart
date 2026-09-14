import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_shop_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NearbyPharmacyScreen extends StatefulWidget {
  const NearbyPharmacyScreen({super.key});

  @override
  State<NearbyPharmacyScreen> createState() => _NearbyPharmacyScreenState();
}

class _NearbyPharmacyScreenState extends State<NearbyPharmacyScreen> {
  final _search = TextEditingController();
  final _pincode = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<PharmacyProvider>().loadStores(
        pincode: _pincode.text.trim(),
        query: _search.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Online Pharmacies'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _refresh(),
              decoration: InputDecoration(
                labelText: 'Search pharmacy',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _refresh),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pincode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Delivery pincode (optional)',
                prefixIcon: const Icon(Icons.location_on_outlined),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.error != null) Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(provider.error!, style: const TextStyle(color: Colors.red)),
            ),
            if (!provider.isLoading && provider.stores.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: Text('No online pharmacies are available for this search.')),
              ),
            ...provider.stores.map((store) {
              final address = store['address'] is Map ? Map<String, dynamic>.from(store['address']) : <String, dynamic>{};
              final ecommerce = store['ecommerce'] is Map ? Map<String, dynamic>.from(store['ecommerce']) : <String, dynamic>{};
              final eta = ecommerce['estimatedDeliveryMinutes'];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: AppConstants.primaryColor.withOpacity(.1),
                    child: const Icon(Icons.local_pharmacy_outlined, color: AppConstants.primaryColor),
                  ),
                  title: Text((store['name'] ?? 'Pharmacy').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([
                    address['city'],
                    address['pincode'],
                    if (eta != null) '~$eta min delivery',
                  ].where((e) => e != null && e.toString().isNotEmpty).join(' • ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.read<PharmacyProvider>().selectStore(store);
                    if (!context.mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyShopScreen()));
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
