import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_cart_screen.dart';
import 'package:aadya_plus/screens/pharmacy/nearby_pharmacy_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PharmacyShopScreen extends StatefulWidget {
  const PharmacyShopScreen({super.key});
  @override
  State<PharmacyShopScreen> createState() => _PharmacyShopScreenState();
}

class _PharmacyShopScreenState extends State<PharmacyShopScreen> {
  final _search = TextEditingController();
  String _rx = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<PharmacyProvider>().loadCatalog(
        query: _search.text.trim(),
        rx: _rx.isEmpty ? null : _rx,
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final store = provider.selectedStore;
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicines')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NearbyPharmacyScreen())),
            child: const Text('Select a pharmacy'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Medicines', style: TextStyle(fontWeight: FontWeight.w800)),
          Text((store['name'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
        ]),
        actions: [
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyCartScreen())),
            ),
            if (provider.cartCount > 0)
              Positioned(right: 4, top: 4, child: CircleAvatar(radius: 9, backgroundColor: Colors.red, child: Text('${provider.cartCount}', style: const TextStyle(fontSize: 10, color: Colors.white)))),
          ]),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search medicine, generic, brand or composition',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              ChoiceChip(label: const Text('All'), selected: _rx.isEmpty, onSelected: (_) { setState(() => _rx = ''); _load(); }),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('OTC'), selected: _rx == 'otc', onSelected: (_) { setState(() => _rx = 'otc'); _load(); }),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Prescription'), selected: _rx == 'required', onSelected: (_) { setState(() => _rx = 'required'); _load(); }),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyPharmacyScreen())),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Change'),
              ),
            ]),
          ]),
        ),
        if (provider.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: provider.products.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No medicines found.'))])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    itemCount: provider.products.length,
                    itemBuilder: (context, index) {
                      final p = provider.products[index];
                      final name = (p['medicineName'] ?? 'Medicine').toString();
                      final generic = (p['genericName'] ?? '').toString();
                      final unitPrice = _double(p['finalUnitPrice'] ?? p['sellingPrice']);
                      final stock = _int(p['quantity']);
                      final rx = p['prescriptionRequired'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.medication_outlined, color: AppConstants.primaryColor)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (generic.isNotEmpty) Text(generic, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 5),
                              Wrap(spacing: 8, children: [
                                Text('₹${unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.primaryColor)),
                                if (rx) const Text('Rx required', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700)),
                                Text('$stock in stock', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ]),
                            ])),
                            IconButton.filled(
                              onPressed: stock <= 0 ? null : () async {
                                try {
                                  await context.read<PharmacyProvider>().addToCart(p);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to server cart.')));
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                                }
                              },
                              icon: const Icon(Icons.add_shopping_cart),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
}
