import 'dart:convert';

import 'package:aadya_plus/models/payment_record.dart';
import 'package:aadya_plus/services/api_client.dart' as http;

class PaymentApiException implements Exception {
  final String message;
  final int statusCode;

  const PaymentApiException(this.message, {required this.statusCode});

  @override
  String toString() => message;
}

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  Future<PaymentOrderData> createOrder({
    required String entityType,
    required String entityId,
  }) async {
    final response = await http.post(
      http.apiUri('/payment/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'entityType': entityType,
        'entityId': entityId,
        'currency': 'INR',
      }),
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);

    final order = Map<String, dynamic>.from(data['order'] ?? const {});
    final payable = Map<String, dynamic>.from(data['payable'] ?? const {});
    final orderId = (order['id'] ?? '').toString();
    if (orderId.isEmpty) {
      throw const PaymentApiException(
        'Payment gateway did not return an order ID.',
        statusCode: 500,
      );
    }

    return PaymentOrderData(
      orderId: orderId,
      amountPaise: _asInt(order['amount']),
      currency: (order['currency'] ?? payable['currency'] ?? 'INR').toString(),
      payableAmount: _asDouble(payable['amount']),
      entityType: (payable['entityType'] ?? entityType).toString(),
      entityId: (payable['entityId'] ?? entityId).toString(),
    );
  }

  Future<void> verify({
    required String orderId,
    required String paymentId,
    required String signature,
    required String entityType,
    required String entityId,
  }) async {
    final response = await http.post(
      http.apiUri('/payment/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'order_id': orderId,
        'payment_id': paymentId,
        'signature': signature,
        'entityType': entityType,
        'entityId': entityId,
      }),
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);
  }

  Future<List<PaymentRecord>> history() async {
    final response = await http.get(
      http.apiUri('/payment/history', queryParameters: {'limit': 100}),
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);
    final rows = data['payments'] is List ? data['payments'] as List : const [];
    return rows
        .whereType<Map>()
        .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  void _assertSuccess(int statusCode, Map<String, dynamic> data) {
    if (statusCode >= 200 && statusCode < 300 && data['success'] == true) return;
    throw PaymentApiException(
      (data['message'] ?? data['error'] ?? 'Payment request failed').toString(),
      statusCode: statusCode,
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
