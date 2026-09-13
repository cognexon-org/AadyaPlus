import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aadya_plus/models/pharmacy_product.dart';
import 'package:aadya_plus/utils/constants.dart';

class PharmacyCategory {
  final String id;
  final String name;
  final IconData icon;
  final int count;
  final Color color;

  PharmacyCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.count = 0,
    required this.color,
  });
}

class PharmacyProvider with ChangeNotifier {
  List<PharmacyProduct> _featuredProducts = [];
  List<PharmacyProduct> _dealsProducts = [];
  List<PharmacyProduct> _allProducts = [];
  List<CartItem> _cartItems = [];
  List<String> _wishlistIds = [];
  bool _isLoading = false;

  List<PharmacyProduct> get featuredProducts => _featuredProducts;
  List<PharmacyProduct> get dealsProducts => _dealsProducts;
  List<PharmacyProduct> get allProducts => _allProducts;
  List<CartItem> get cartItems => _cartItems;
  List<String> get wishlistIds => _wishlistIds;
  bool get isLoading => _isLoading;

  int get cartCount =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get cartSubtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get cartDiscount =>
      _cartItems.fold(0.0, (sum, item) =>
          sum + (item.product.savings * item.quantity));

  double get deliveryFee => cartSubtotal > 499 ? 0 : 49;

  double get cartTotal => cartSubtotal + deliveryFee;

  List<PharmacyCategory> get categories => [
        PharmacyCategory(
            id: '1',
            name: 'Tablets',
            icon: Icons.medication,
            count: 245,
            color: Colors.blue),
        PharmacyCategory(
            id: '2',
            name: 'Capsules',
            icon: Icons.circle,
            count: 189,
            color: Colors.purple),
        PharmacyCategory(
            id: '3',
            name: 'Syrups',
            icon: Icons.local_drink,
            count: 156,
            color: Colors.green),
        PharmacyCategory(
            id: '4',
            name: 'Injections',
            icon: Icons.vaccines,
            count: 98,
            color: Colors.red),
        PharmacyCategory(
            id: '5',
            name: 'Ointments',
            icon: Icons.healing,
            count: 134,
            color: Colors.amber),
        PharmacyCategory(
            id: '6',
            name: 'Drops',
            icon: Icons.water_drop,
            count: 167,
            color: Colors.indigo),
        PharmacyCategory(
            id: '7',
            name: 'Inhalers',
            icon: Icons.air,
            count: 76,
            color: Colors.cyan),
        PharmacyCategory(
            id: '8',
            name: 'Vitamins',
            icon: Icons.eco,
            count: 203,
            color: Colors.teal),
      ];

  PharmacyProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      
      final response = await http.get(
        Uri.parse(AppConstants.medicinesUrl), // Need to ensure constants.dart has medicinesUrl
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> meds = responseData['medicines'] ?? responseData['data'] ?? [];

        final List<PharmacyProduct> fetchedProducts = meds.map((doc) {
          return PharmacyProduct(
            id: doc['_id'] ?? '',
            name: doc['medicineName'] ?? 'Unknown',
            category: doc['category'] != null ? doc['category'].toString().toUpperCase() : 'OTHER',
            brand: doc['brandName'] ?? doc['manufacturer'] ?? 'Unknown Brand',
            price: doc['sellingPrice']?.toDouble() ?? 0.0,
            discount: doc['discount']?.toDouble() ?? 0.0,
            rating: 0.0, // Backend might not have ratings yet
            reviews: 0,
            stock: doc['quantity'] ?? 0,
            packSize: '${doc['strength'] ?? ''} ${doc['unit'] ?? ''}'.trim(),
            prescriptionRequired: doc['prescriptionRequired'] ?? false,
          );
        }).toList();

        // Split them up simply for the UI. (Featured = top 5, Deals = ones with discount)
        if (fetchedProducts.length >= 5) {
           _featuredProducts = fetchedProducts.take(5).toList();
        } else {
           _featuredProducts = fetchedProducts;
        }

        _dealsProducts = fetchedProducts.where((p) => p.discount > 0).toList();
        _allProducts = fetchedProducts;
      } else {
        print('Backend error loading pharmacy: ${responseData['message']}');
      }
    } catch (e) {
      print('HTTP error loading medicines: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  List<PharmacyProduct> searchProducts(String query) {
    if (query.isEmpty) return _allProducts;
    final q = query.toLowerCase();
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
    }).toList();
  }

  List<PharmacyProduct> getProductsByCategory(String category) {
    if (category.isEmpty || category.toLowerCase() == 'all') {
      return _allProducts;
    }
    return _allProducts
        .where((p) => p.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  void addToCart(PharmacyProduct product, {int quantity = 1}) {
    final existingIndex =
        _cartItems.indexWhere((item) => item.product.id == product.id);
    if (existingIndex != -1) {
      _cartItems[existingIndex].quantity += quantity;
    } else {
      _cartItems.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateCartQuantity(String productId, int quantity) {
    final index =
        _cartItems.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  bool isInWishlist(String productId) => _wishlistIds.contains(productId);

  void toggleWishlist(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    notifyListeners();
  }
}
