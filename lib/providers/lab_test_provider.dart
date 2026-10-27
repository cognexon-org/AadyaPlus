import 'package:aadya_plus/services/diagnostics_service.dart';
import 'package:flutter/material.dart';

class LabTestProvider with ChangeNotifier {
  final DiagnosticsService _api = DiagnosticsService.instance;

  List<Map<String, dynamic>> _catalog = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get catalog => _catalog;
  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  LabTestProvider() {
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait([searchCatalog(), loadOrders()]);
  }

  Future<void> searchCatalog({String? query, bool homeCollection = false, String? pincode}) async {
    await _run(() async {
      _catalog = await _api.searchCatalog(query: query, homeCollection: homeCollection, pincode: pincode);
    });
  }

  Future<List<Map<String, dynamic>>> slots(String labId, DateTime date) => _api.slots(labId, date);

  // ── Test cart ──
  // A lab order holds tests and packages from one lab, so the cart does too.

  final List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> get cart => List.unmodifiable(_cart);
  String? get cartLabId => _cart.isEmpty ? null : (_cart.first['labId'] ?? '').toString();
  Map<String, dynamic>? get cartLab => _cart.isEmpty ? null : _cart.first;

  static String itemKey(Map<String, dynamic> row) {
    final item = Map<String, dynamic>.from(row['item'] ?? const {});
    final code = row['kind'] == 'package' ? item['packageCode'] : item['testCode'];
    return '${row['labId']}|${row['kind']}|$code';
  }

  bool inCart(Map<String, dynamic> row) => _cart.any((r) => itemKey(r) == itemKey(row));

  double get cartSubtotal => _cart.fold(0.0, (s, r) {
    final price = (r['item'] is Map ? r['item']['price'] : null);
    return s + (price is num ? price.toDouble() : double.tryParse('$price') ?? 0);
  });

  /// Adds [row]; false (and nothing changes) when it's from another lab.
  bool addToCart(Map<String, dynamic> row) {
    if (inCart(row)) return true;
    if (cartLabId != null && cartLabId != (row['labId'] ?? '').toString()) return false;
    _cart.add(row);
    notifyListeners();
    return true;
  }

  void replaceCart(Map<String, dynamic> row) {
    _cart
      ..clear()
      ..add(row);
    notifyListeners();
  }

  void removeFromCart(Map<String, dynamic> row) {
    _cart.removeWhere((r) => itemKey(r) == itemKey(row));
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Books everything in the cart as one order at one lab.
  Future<Map<String, dynamic>> bookCart({
    required DateTime date,
    required String startTime,
    required String endTime,
    required String type,
    Map<String, dynamic>? collectionAddress,
    String? patientInstructions,
  }) async {
    String code(Map<String, dynamic> r) {
      final item = Map<String, dynamic>.from(r['item'] ?? const {});
      return ((r['kind'] == 'package' ? item['packageCode'] : item['testCode']) ?? '').toString();
    }

    final order = await _api.createOrder(
      labId: cartLabId ?? '',
      testCodes: _cart.where((r) => r['kind'] != 'package').map(code).where((c) => c.isNotEmpty).toList(),
      packageCodes: _cart.where((r) => r['kind'] == 'package').map(code).where((c) => c.isNotEmpty).toList(),
      date: date,
      startTime: startTime,
      endTime: endTime,
      type: type,
      collectionAddress: collectionAddress,
      patientInstructions: patientInstructions,
    );
    _cart.clear();
    await loadOrders();
    return order;
  }

  Future<Map<String, dynamic>> book({
    required Map<String, dynamic> catalogItem,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String type,
    Map<String, dynamic>? collectionAddress,
    String? patientInstructions,
  }) async {
    final kind = (catalogItem['kind'] ?? '').toString();
    final item = Map<String, dynamic>.from(catalogItem['item'] ?? const {});
    final code = (kind == 'package' ? item['packageCode'] : item['testCode'])?.toString() ?? '';
    final order = await _api.createOrder(
      labId: (catalogItem['labId'] ?? '').toString(),
      testCodes: kind == 'test' && code.isNotEmpty ? [code] : const [],
      packageCodes: kind == 'package' && code.isNotEmpty ? [code] : const [],
      date: date,
      startTime: startTime,
      endTime: endTime,
      type: type,
      collectionAddress: collectionAddress,
      patientInstructions: patientInstructions,
    );
    await loadOrders();
    return order;
  }

  Future<void> loadOrders({String? status}) async {
    try {
      _orders = await _api.orders(status: status);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getOrder(String id) => _api.order(id);

  Future<void> cancelOrder(String id) async {
    await _api.cancel(id);
    await loadOrders();
  }

  Future<Map<String, dynamic>> reschedule({
    required String id,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final order = await _api.reschedule(id: id, date: date, startTime: startTime, endTime: endTime);
    await loadOrders();
    return order;
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

  @visibleForTesting
  void debugSeedCatalog(List<Map<String, dynamic>> rows, {int inCart = 0}) {
    _catalog = rows;
    _cart
      ..clear()
      ..addAll(rows.take(inCart));
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugSeedOrders(List<Map<String, dynamic>> orders) {
    _orders = orders;
    notifyListeners();
  }
}
