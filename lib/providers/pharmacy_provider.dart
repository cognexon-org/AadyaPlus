import 'package:aadya_plus/services/e_pharmacy_service.dart';
import 'package:flutter/material.dart';

class PharmacyProvider with ChangeNotifier {
  final EPharmacyService _api = EPharmacyService.instance;

  List<Map<String, dynamic>> _stores = [];
  Map<String, dynamic>? _selectedStore;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic> _cartTotals = {};
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _uploads = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get stores => _stores;
  Map<String, dynamic>? get selectedStore => _selectedStore;
  List<Map<String, dynamic>> get products => _products;
  List<Map<String, dynamic>> get cartItems => _cartItems;
  Map<String, dynamic> get cartTotals => _cartTotals;
  List<Map<String, dynamic>> get addresses => _addresses;
  List<Map<String, dynamic>> get prescriptions => _prescriptions;
  List<Map<String, dynamic>> get uploads => _uploads;
  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get cartCount => _asInt(_cartTotals['itemCount']);
  double get cartSubtotal => _asDouble(_cartTotals['merchandiseTotal']);

  PharmacyProvider() {
    bootstrap();
  }

  Future<void> bootstrap() async {
    await loadStores();
    await loadCart();
    await loadOrders();
  }

  Future<void> loadStores({String? pincode, String? query}) async {
    await _run(() async {
      _stores = await _api.listStores(pincode: pincode, query: query);
      if (_selectedStore == null && _stores.isNotEmpty) {
        _selectedStore = _stores.first;
        await _loadCatalogInternal();
      } else if (_selectedStore != null) {
        final selectedId = _id(_selectedStore);
        final match = _stores.where((s) => _id(s) == selectedId).toList();
        if (match.isNotEmpty) _selectedStore = match.first;
      }
    });
  }

  Future<void> selectStore(Map<String, dynamic> store) async {
    _selectedStore = store;
    _products = [];
    notifyListeners();
    await loadCatalog();
  }

  Future<void> loadCatalog({String? query, String? category, String? rx}) async {
    await _run(() => _loadCatalogInternal(query: query, category: category, rx: rx));
  }

  Future<void> _loadCatalogInternal({String? query, String? category, String? rx}) async {
    final storeId = _id(_selectedStore);
    if (storeId.isEmpty) {
      _products = [];
      return;
    }
    final data = await _api.catalog(
      storeId: storeId,
      query: query,
      category: category,
      rx: rx,
    );
    _products = _list(data['products']);
  }

  Future<void> loadCart() async {
    try {
      final data = await _api.getCart();
      _cartItems = _list(data['items']);
      _cartTotals = Map<String, dynamic>.from(data['totals'] ?? const {});
      final store = data['store'];
      if (store is Map) {
        final hydratedStore = Map<String, dynamic>.from(store);
        if (_cartItems.isNotEmpty || _selectedStore == null) _selectedStore = hydratedStore;
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      // A brand-new patient can legitimately have no cart yet. Keep the UI empty.
      _cartItems = [];
      _cartTotals = {};
      notifyListeners();
    }
  }

  Future<void> addToCart(Map<String, dynamic> product, {int quantity = 1}) async {
    final storeId = _id(_selectedStore);
    final medicineId = _id(product);
    if (storeId.isEmpty || medicineId.isEmpty) throw Exception('Select a pharmacy before adding medicines.');
    try {
      final data = await _api.addCartItem(storeId: storeId, medicineId: medicineId, quantity: quantity);
      _applyCart(data);
    } on EPharmacyApiException catch (e) {
      if (e.code == 'CART_STORE_CONFLICT') {
        throw Exception('${e.message} Open the cart and clear it before switching pharmacy.');
      }
      rethrow;
    }
  }

  Future<void> updateCartQuantity(String medicineId, int quantity) async {
    final data = await _api.updateCartItem(medicineId, quantity);
    _applyCart(data);
  }

  Future<void> removeFromCart(String medicineId) async {
    final data = await _api.removeCartItem(medicineId);
    _applyCart(data);
  }

  Future<void> clearCart() async {
    await _api.clearCart();
    _cartItems = [];
    _cartTotals = {};
    notifyListeners();
  }

  Future<void> loadCheckoutData() async {
    await _run(() async {
      final results = await Future.wait([
        _api.addresses(),
        _api.prescriptions(),
        _api.prescriptionUploads(),
      ]);
      _addresses = results[0];
      _prescriptions = results[1];
      _uploads = results[2];
    });
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> payload) async {
    final address = await _api.createAddress(payload);
    await loadCheckoutData();
    return address;
  }

  Future<Map<String, dynamic>> uploadPrescription(String filePath) async {
    final upload = await _api.uploadPrescription(filePath);
    await loadCheckoutData();
    return upload;
  }

  Future<Map<String, dynamic>> quote({
    required String addressId,
    required String paymentMethod,
    String? couponCode,
    String? prescriptionId,
    String? prescriptionUploadId,
  }) {
    return _api.checkoutQuote(
      addressId: addressId,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      prescriptionId: prescriptionId,
      prescriptionUploadId: prescriptionUploadId,
    );
  }

  Future<Map<String, dynamic>> placeOrder({
    required String addressId,
    required String paymentMethod,
    String? couponCode,
    String? prescriptionId,
    String? prescriptionUploadId,
    String? deliveryInstructions,
  }) async {
    final order = await _api.createOrder(
      addressId: addressId,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      prescriptionId: prescriptionId,
      prescriptionUploadId: prescriptionUploadId,
      deliveryInstructions: deliveryInstructions,
    );
    _cartItems = [];
    _cartTotals = {};
    await loadOrders();
    notifyListeners();
    return order;
  }

  Future<void> loadOrders() async {
    try {
      _orders = await _api.orders();
      notifyListeners();
    } catch (_) {
      // Orders are secondary to app startup. Individual order screens surface errors.
    }
  }

  Future<Map<String, dynamic>> refreshOrder(String id) => _api.order(id);

  Future<void> cancelOrder(String id) async {
    await _api.cancelOrder(id);
    await loadOrders();
  }

  Future<void> reorder(String id) async {
    await _api.reorder(id);
    await loadCart();
  }

  void _applyCart(Map<String, dynamic> data) {
    _cartItems = _list(data['items']);
    _cartTotals = Map<String, dynamic>.from(data['totals'] ?? const {});
    final store = data['store'];
    if (store is Map) _selectedStore = Map<String, dynamic>.from(store);
    _error = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() operation) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _id(Map<String, dynamic>? value) => (value?['_id'] ?? value?['id'] ?? '').toString();
  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  static int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static double _asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
