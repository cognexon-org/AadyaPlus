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
}
