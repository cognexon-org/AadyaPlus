import 'package:flutter/material.dart';
import 'package:aadya_plus/models/medicine.dart';

class MedicineProvider with ChangeNotifier {
  List<Medicine> _medicines = [];
  List<Medicine> _cartItems = [];
  bool _isLoading = false;

  List<Medicine> get medicines => _medicines;
  List<Medicine> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  double get cartTotal {
    return _cartItems.fold(0, (total, item) => total + item.discountPrice);
  }

  MedicineProvider() {
    loadMedicines();
  }

  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _medicines = [
      Medicine(
        id: '1',
        name: 'Paracetamol 500mg',
        manufacturer: 'Cipla',
        description: 'Pain reliever and fever reducer',
        dosage: '1 tablet every 4-6 hours',
        price: 50,
        discountPrice: 45,
        stock: 100,
        imageUrl: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400',
        requiresPrescription: false,
        categories: ['Pain Relief', 'Fever'],
      ),
      Medicine(
        id: '2',
        name: 'Azithromycin 250mg',
        manufacturer: 'Sun Pharma',
        description: 'Antibiotic for bacterial infections',
        dosage: '1 tablet daily for 5 days',
        price: 120,
        discountPrice: 100,
        stock: 50,
        imageUrl: 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=400',
        requiresPrescription: true,
        categories: ['Antibiotic'],
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  void addToCart(Medicine medicine) {
    _cartItems.add(medicine);
    notifyListeners();
  }

  void removeFromCart(String medicineId) {
    _cartItems.removeWhere((item) => item.id == medicineId);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  List<Medicine> searchMedicines(String query) {
    if (query.isEmpty) return _medicines;
    return _medicines
        .where((medicine) =>
            medicine.name.toLowerCase().contains(query.toLowerCase()) ||
            medicine.manufacturer.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}