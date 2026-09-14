import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/pharmacy/epharmacy_checkout_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PharmacyCartScreen extends StatefulWidget {
  const PharmacyCartScreen({super.key});
  @override
  State<PharmacyCartScreen> createState() => _PharmacyCartScreenState();
}

class _PharmacyCartScreenState extends State<PharmacyCartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PharmacyProvider>().loadCart());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Your Cart')),
      body: provider.cartItems.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: provider.cartItems.length,
                  itemBuilder: (context, index) {
                    final line = provider.cartItems[index];
                    final medicine = line['medicine'] is Map ? Map<String, dynamic>.from(line['medicine']) : <String, dynamic>{};
                    final id = (medicine['_id'] ?? line['medicineId'] ?? '').toString();
                    final qty = _int(line['quantity']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.medication_outlined, color: AppConstants.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text((medicine['medicineName'] ?? 'Medicine').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('₹${_double(line['totalAmount']).toStringAsFixed(2)}', style: const TextStyle(color: AppConstants.primaryColor)),
                            if (medicine['prescriptionRequired'] == true) const Text('Prescription required', style: TextStyle(fontSize: 11, color: Colors.orange)),
                          ])),
                          IconButton(onPressed: qty <= 1 ? null : () => provider.updateCartQuantity(id, qty - 1), icon: const Icon(Icons.remove_circle_outline)),
                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => provider.updateCartQuantity(id, qty + 1), icon: const Icon(Icons.add_circle_outline)),
                          IconButton(onPressed: () => provider.removeFromCart(id), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  color: Colors.white,
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Current merchandise total', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹${provider.cartSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EPharmacyCheckoutScreen())),
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: const Text('Checkout securely'),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }

  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
}
