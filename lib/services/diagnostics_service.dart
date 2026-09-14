import 'dart:convert';

import 'package:aadya_plus/services/api_client.dart' as http;

class DiagnosticsApiException implements Exception {
  final String message;
  final int statusCode;
  const DiagnosticsApiException(this.message, {required this.statusCode});
  @override
  String toString() => message;
}

class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  Future<List<Map<String, dynamic>>> searchCatalog({
    String? query,
    String? city,
    String? pincode,
    bool homeCollection = false,
  }) async {
    final response = await http.get(http.apiUri('/diagnostics/search', queryParameters: {
      if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      if (pincode?.trim().isNotEmpty == true) 'pincode': pincode!.trim(),
      if (homeCollection) 'homeCollection': 'true',
    }));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['items']);
  }

  Future<List<Map<String, dynamic>>> labs({String? query, String? city, String? pincode}) async {
    final response = await http.get(http.apiUri('/diagnostics/labs', queryParameters: {
      if (query?.trim().isNotEmpty == true) 'search': query!.trim(),
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      if (pincode?.trim().isNotEmpty == true) 'pincode': pincode!.trim(),
      'limit': 50,
    }));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['labs']);
  }

  Future<List<Map<String, dynamic>>> slots(String labId, DateTime date) async {
    final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(http.apiUri('/diagnostics/labs/$labId/slots', queryParameters: {'date': key}));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['slots']);
  }

  Future<Map<String, dynamic>> createOrder({
    required String labId,
    required List<String> testCodes,
    required List<String> packageCodes,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String type,
    Map<String, dynamic>? collectionAddress,
    String? patientInstructions,
  }) async {
    final dateKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      http.apiUri('/diagnostics/orders'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'labId': labId,
        'testCodes': testCodes,
        'packageCodes': packageCodes,
        'date': dateKey,
        'startTime': startTime,
        'endTime': endTime,
        'type': type,
        if (collectionAddress != null) 'collectionAddress': collectionAddress,
        if (patientInstructions?.trim().isNotEmpty == true) 'patientInstructions': patientInstructions!.trim(),
      }),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
  }

  Future<List<Map<String, dynamic>>> orders({String? status}) async {
    final response = await http.get(http.apiUri('/diagnostics/orders', queryParameters: {
      if (status?.trim().isNotEmpty == true) 'status': status!.trim(),
      'limit': 100,
    }));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return _list(data['orders']);
  }

  Future<Map<String, dynamic>> order(String id) async {
    final response = await http.get(http.apiUri('/diagnostics/orders/$id'));
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
  }

  Future<Map<String, dynamic>> cancel(String id, {String? reason}) async {
    final response = await http.post(
      http.apiUri('/diagnostics/orders/$id/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'reason': reason ?? 'Cancelled from AadyaPlus mobile app'}),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
  }

  Future<Map<String, dynamic>> reschedule({
    required String id,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final dateKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      http.apiUri('/diagnostics/orders/$id/reschedule'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'date': dateKey, 'startTime': startTime, 'endTime': endTime}),
    );
    final data = _decode(response.body);
    _assert(response.statusCode, data);
    return Map<String, dynamic>.from(data['order'] ?? const {});
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
    throw DiagnosticsApiException(
      (data['message'] ?? data['error'] ?? 'Diagnostics request failed').toString(),
      statusCode: statusCode,
    );
  }
}
