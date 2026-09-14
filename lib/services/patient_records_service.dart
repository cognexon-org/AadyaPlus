import 'dart:convert';
import 'dart:io';

import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PatientRecordsBundle {
  final Map<String, dynamic> medicalHistory;
  final List<Map<String, dynamic>> labReports;
  final List<Map<String, dynamic>> invoices;

  const PatientRecordsBundle({
    required this.medicalHistory,
    required this.labReports,
    required this.invoices,
  });
}

class PatientRecordsService {
  PatientRecordsService._();
  static final PatientRecordsService instance = PatientRecordsService._();

  Future<PatientRecordsBundle> load() async {
    final responses = await Future.wait([
      http.get(http.apiUri('/patient/medical-history')),
      http.get(http.apiUri('/patient/lab-reports', queryParameters: {'limit': 100})),
      http.get(http.apiUri('/patient/invoices', queryParameters: {'limit': 100})),
    ]);

    final history = _decode(responses[0].body);
    final reports = _decode(responses[1].body);
    final invoices = _decode(responses[2].body);

    _assertSuccess(responses[0].statusCode, history);
    _assertSuccess(responses[1].statusCode, reports);
    _assertSuccess(responses[2].statusCode, invoices);

    return PatientRecordsBundle(
      medicalHistory: Map<String, dynamic>.from(history['medicalHistory'] ?? const {}),
      labReports: _mapList(reports['labTests']),
      invoices: _mapList(invoices['invoices']),
    );
  }

  Future<String> downloadAndOpenLabReport(String labTestId) async {
    final response = await http.get(http.apiUri('/diagnostics/orders/$labTestId/report'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = _decode(response.body);
      throw Exception((payload['error'] ?? payload['message'] ?? 'Lab report is not available').toString());
    }
    final contentType = response.headers['content-type'] ?? 'application/pdf';
    final extension = contentType.contains('pdf') ? 'pdf' : 'bin';
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/diagnostic_report_$labTestId.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await OpenFilex.open(file.path, type: contentType);
    return file.path;
  }

  Future<void> addMedicalRecord({
    required String recordType,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.post(
      http.apiUri('/patient/medical-history'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'recordType': recordType, 'data': data}),
    );
    final payload = _decode(response.body);
    _assertSuccess(response.statusCode, payload);
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  static void _assertSuccess(int statusCode, Map<String, dynamic> data) {
    if (statusCode >= 200 && statusCode < 300 && data['success'] == true) return;
    throw Exception((data['error'] ?? data['message'] ?? 'Unable to load health records').toString());
  }
}
