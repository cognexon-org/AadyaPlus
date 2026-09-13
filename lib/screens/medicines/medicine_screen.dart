import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/medicine_provider.dart';
import 'package:aadya_plus/models/medicine.dart';
import 'package:aadya_plus/widgets/medicine_card.dart';
import 'package:aadya_plus/utils/constants.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = Provider.of<MedicineProvider>(context, listen: false);
    provider.searchMedicines(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        elevation: 0,
        title: const Text('Medicines', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () => _showCart(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                cursorColor: AppConstants.primaryColor,
                decoration: InputDecoration(
                  hintText: 'Search medicines...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: AppConstants.primaryColor, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.2), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<MedicineProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final medicines = _searchController.text.isEmpty
                    ? provider.medicines
                    : provider.searchMedicines(_searchController.text);

                if (medicines.isEmpty) {
                  return const Center(
                    child: Text('No medicines found'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = medicines[index];
                    return MedicineCard(
                      medicine: medicine,
                      onAddToCart: () {
                        provider.addToCart(medicine);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${medicine.name} added to cart'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCart(BuildContext context) {
    final provider = Provider.of<MedicineProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Shopping Cart',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (provider.cartItems.isEmpty)
                const Text('Your cart is empty')
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = provider.cartItems[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(item.imageUrl),
                        ),
                        title: Text(item.name),
                        subtitle: Text('₹${item.discountPrice}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: () {
                            provider.removeFromCart(item.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
              if (provider.cartItems.isNotEmpty) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${provider.cartTotal}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement checkout
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B8B1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Proceed to Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}