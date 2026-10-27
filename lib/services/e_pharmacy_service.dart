import 'dart:convert';

import 'package:aadya_plus/services/api_client.dart' as http;

class EPharmacyApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  const EPharmacyApiException(this.message, {required this.statusCode, this.code});

  @override
  String toString() => message;
}

class EPharmacyService {
  EPharmacyService._();
  static final EPharmacyService instance = EPharmacyService._();

  Future<List<Map<String, dynamic>>> listStores({String? city, String? pincode, String? query}) async {
    final response = await http.get(http.apiUri('/epharmacy/stores', queryParameters: {
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      if (pincode?.trim().isNotEmpty == true) 'pincode': pincode!.trim(),
      if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
    }));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['stores']);
  }

  Future<Map<String, dynamic>> catalog({
    required String storeId,
    String? query,
    String? category,
    String? rx,
    int page = 1,
    int limit = 100,
  }) async {
    final response = await http.get(http.apiUri('/epharmacy/catalog', queryParameters: {
      'storeId': storeId,
      if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
      if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
      if (rx?.trim().isNotEmpty == true) 'rx': rx!.trim(),
      'page': page,
      'limit': limit,
    }));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return data;
  }

  Future<Map<String, dynamic>> getCart() async {
    final response = await http.get(http.apiUri('/epharmacy/cart'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return data;
  }

  Future<Map<String, dynamic>> addCartItem({
    required String storeId,
    required String medicineId,
    int quantity = 1,
  }) async {
    final response = await http.post(
      http.apiUri('/epharmacy/cart/items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'storeId': storeId, 'medicineId': medicineId, 'quantity': quantity}),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return data;
  }

  Future<Map<String, dynamic>> updateCartItem(String medicineId, int quantity) async {
    final response = await http.patch(
      http.apiUri('/epharmacy/cart/items/$medicineId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'quantity': quantity}),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return data;
  }

  Future<Map<String, dynamic>> removeCartItem(String medicineId) async {
    final response = await http.delete(http.apiUri('/epharmacy/cart/items/$medicineId'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return data;
  }

  Future<void> clearCart() async {
    final response = await http.delete(http.apiUri('/epharmacy/cart'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
  }

  Future<void> setCartPrescription({String? prescriptionId, String? prescriptionUploadId}) async {
    final response = await http.put(
      http.apiUri('/epharmacy/cart/prescription'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'prescriptionId': prescriptionId,
        'prescriptionUploadId': prescriptionUploadId,
      }),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
  }

  Future<List<Map<String, dynamic>>> addresses() async {
    final response = await http.get(http.apiUri('/epharmacy/addresses'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['addresses']);
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> payload) async {
    final response = await http.post(
      http.apiUri('/epharmacy/addresses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['address'] ?? const {});
  }

  Future<void> deleteAddress(String id) async {
    final response = await http.delete(http.apiUri('/epharmacy/addresses/$id'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
  }

  Future<void> setDefaultAddress(String id) async {
    final response = await http.post(http.apiUri('/epharmacy/addresses/$id/default'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
  }

  Future<List<Map<String, dynamic>>> prescriptions() async {
    final response = await http.get(http.apiUri('/epharmacy/prescriptions'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['prescriptions']);
  }

  Future<List<Map<String, dynamic>>> prescriptionUploads() async {
    final response = await http.get(http.apiUri('/epharmacy/prescription-uploads'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['uploads']);
  }

  Future<Map<String, dynamic>> uploadPrescription(String filePath) async {
    final response = await http.multipartPost(
      http.apiUri('/epharmacy/prescription-uploads'),
      fileField: 'prescription',
      filePath: filePath,
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['upload'] ?? const {});
  }

  Future<Map<String, dynamic>> checkoutQuote({
    required String addressId,
    required String paymentMethod,
    String? couponCode,
    String? prescriptionId,
    String? prescriptionUploadId,
  }) async {
    final response = await http.post(
      http.apiUri('/epharmacy/checkout/quote'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'addressId': addressId,
        'paymentMethod': paymentMethod,
        if (couponCode?.trim().isNotEmpty == true) 'couponCode': couponCode!.trim(),
        if (prescriptionId?.isNotEmpty == true) 'prescriptionId': prescriptionId,
        if (prescriptionUploadId?.isNotEmpty == true) 'prescriptionUploadId': prescriptionUploadId,
      }),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['quote'] ?? const {});
  }

  Future<Map<String, dynamic>> createOrder({
    required String addressId,
    required String paymentMethod,
    String? couponCode,
    String? prescriptionId,
    String? prescriptionUploadId,
    String? deliveryInstructions,
  }) async {
    final response = await http.post(
      http.apiUri('/epharmacy/orders'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'addressId': addressId,
        'paymentMethod': paymentMethod,
        if (couponCode?.trim().isNotEmpty == true) 'couponCode': couponCode!.trim(),
        if (prescriptionId?.isNotEmpty == true) 'prescriptionId': prescriptionId,
        if (prescriptionUploadId?.isNotEmpty == true) 'prescriptionUploadId': prescriptionUploadId,
        if (deliveryInstructions?.trim().isNotEmpty == true) 'deliveryInstructions': deliveryInstructions!.trim(),
      }),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final response = await http.get(http.apiUri('/epharmacy/orders'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['orders']);
  }

  Future<Map<String, dynamic>> order(String id) async {
    final response = await http.get(http.apiUri('/epharmacy/orders/$id'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
  }

  Future<Map<String, dynamic>> cancelOrder(String id, {String? reason}) async {
    final response = await http.post(
      http.apiUri('/epharmacy/orders/$id/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'reason': reason ?? 'Cancelled from AadyaPlus mobile app'}),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
  }

  Future<void> reorder(String id) async {
    final response = await http.post(http.apiUri('/epharmacy/orders/$id/reorder'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(body);
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _assert(int statusCode, Map<String, dynamic> data) {
    if (statusCode >= 200 && statusCode < 300 && data['success'] == true) return;
    throw EPharmacyApiException(
      (data['message'] ?? data['error'] ?? 'E-pharmacy request failed').toString(),
      statusCode: statusCode,
      code: data['code']?.toString(),
    );
  }
}
