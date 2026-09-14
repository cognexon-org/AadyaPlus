import 'dart:convert';
import 'dart:io';

import 'package:aadya_plus/models/prescription.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PrescriptionProvider with ChangeNotifier {
  List<Prescription> _prescriptions = [];
  bool _isLoading = false;
  String _filter = 'all';
  String? _error;

  List<Prescription> get prescriptions => _getFilteredPrescriptions();
  List<Prescription> get allPrescriptions => _prescriptions;
  bool get isLoading => _isLoading;
  String get filter => _filter;
  String? get error => _error;

  int get totalCount => _prescriptions.length;
  int get activeCount => _prescriptions.where((p) => p.isActive).length;
  int get pendingOrdersCount => _prescriptions
      .where((p) => p.pharmacyStatus == 'not_dispensed' || p.pharmacyStatus == 'partially_dispensed')
      .length;
  int get expiredCount => _prescriptions.where((p) => p.isExpired).length;

  PrescriptionProvider() {
    loadPrescriptions();
  }

  Future<void> loadPrescriptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await http.get(http.apiUri('/prescription', queryParameters: {'limit': 100}));
      final data = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
        final rows = data['prescriptions'] is List ? data['prescriptions'] as List : const [];
        _prescriptions = rows
            .whereType<Map>()
            .map((row) => Prescription.fromJson(Map<String, dynamic>.from(row)))
            .toList();
      } else {
        _error = (data['message'] ?? data['error'] ?? 'Failed to load prescriptions').toString();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Prescription> fetchPrescription(String id) async {
    final response = await http.get(http.apiUri('/prescription/$id'));
    final data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return Prescription.fromJson(Map<String, dynamic>.from(data['prescription'] ?? const {}));
    }
    throw Exception((data['message'] ?? data['error'] ?? 'Failed to load prescription').toString());
  }

  Future<String> downloadAndOpenPdf(Prescription prescription) async {
    final response = await http.get(http.apiUri('/prescription/${prescription.id}/pdf'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _decode(response.body);
      throw Exception((data['message'] ?? data['error'] ?? 'Unable to download prescription PDF').toString());
    }
    final directory = await getTemporaryDirectory();
    final safeNumber = prescription.prescriptionNumber.isNotEmpty
        ? prescription.prescriptionNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        : 'prescription_${prescription.id}';
    final file = File('${directory.path}/$safeNumber.pdf');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await OpenFilex.open(file.path, type: 'application/pdf');
    return file.path;
  }

  List<Prescription> _getFilteredPrescriptions() {
    switch (_filter) {
      case 'active':
        return _prescriptions.where((p) => p.isActive).toList();
      case 'expired':
        return _prescriptions.where((p) => p.isExpired).toList();
      case 'completed':
        return _prescriptions.where((p) => p.pharmacyStatus == 'fully_dispensed').toList();
      default:
        return _prescriptions;
    }
  }

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  List<Prescription> search(String query) {
    if (query.isEmpty) return _getFilteredPrescriptions();
    final q = query.toLowerCase();
    return _getFilteredPrescriptions().where((p) {
      return p.doctorName.toLowerCase().contains(q) ||
          p.diagnosis.any((d) => d.toLowerCase().contains(q)) ||
          p.medicines.any((m) => m.medicineName.toLowerCase().contains(q));
    }).toList();
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
}
