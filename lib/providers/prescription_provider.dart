import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aadya_plus/models/prescription.dart';
import 'package:aadya_plus/utils/constants.dart';

class PrescriptionProvider with ChangeNotifier {
  List<Prescription> _prescriptions = [];
  bool _isLoading = false;
  String _filter = 'all';

  List<Prescription> get prescriptions => _getFilteredPrescriptions();
  List<Prescription> get allPrescriptions => _prescriptions;
  bool get isLoading => _isLoading;
  String get filter => _filter;

  int get totalCount => _prescriptions.length;
  int get activeCount =>
      _prescriptions.where((p) => p.isActive).length;
  int get pendingOrdersCount => _prescriptions
      .where((p) =>
          p.pharmacyStatus == 'not_dispensed' ||
          p.pharmacyStatus == 'partially_dispensed')
      .length;
  int get expiredCount =>
      _prescriptions.where((p) => p.isExpired).length;

  PrescriptionProvider() {
    loadPrescriptions();
  }

  Future<void> loadPrescriptions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return; // Non-auth users have no prescriptions
      }

      final response = await http.get(
        Uri.parse(AppConstants.prescriptionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> prescDocs = responseData['prescriptions'] ?? [];

        _prescriptions = prescDocs.map((doc) {
          final professionalType = doc['professionalType'] ?? 'doctor';
          
          String doctorName = 'Unknown Doc';
          String docSpecialty = 'General';
          
          if (doc['doctorId'] != null && professionalType == 'doctor') {
            doctorName = doc['doctorId']['name'] ?? 'Unknown Doctor';
            docSpecialty = (doc['doctorId']['specialization'] != null && (doc['doctorId']['specialization'] as List).isNotEmpty) ? doc['doctorId']['specialization'][0] : 'General';
          } else if (doc['physioId'] != null && professionalType == 'physio') {
            doctorName = doc['physioId']['name'] ?? 'Unknown Physio';
            docSpecialty = 'Physiotherapy';
          }

          final List<dynamic> backendMeds = doc['medicines'] ?? [];
          final List<PrescribedMedicine> myMeds = backendMeds.map((med) {
             return PrescribedMedicine(
                medicineName: med['medicineName'] ?? 'Unknown',
                genericName: med['genericName'] ?? '',
                dosage: med['dosage'] ?? '',
                frequency: med['frequency'] ?? '',
                duration: med['duration'] ?? '',
                prescribedQuantity: med['quantity'] ?? 0,
                dispensedQuantity: 0, // Could match against doc['dispensedItems']
                instructions: med['instructions'] ?? '',
             );
          }).toList();

          final List<dynamic> backendDiagnosis = doc['diagnosis'] ?? [];

          return Prescription(
            id: doc['_id'] ?? '',
            doctorName: doctorName,
            doctorSpecialization: docSpecialty,
            issuedAt: doc['issuedAt'] != null ? DateTime.parse(doc['issuedAt']) : DateTime.now(),
            validUntil: doc['expiresAt'] != null ? DateTime.parse(doc['expiresAt']) : DateTime.now().add(const Duration(days: 30)),
            status: doc['status'] ?? 'issued',
            pharmacyStatus: doc['pharmacyStatus'] ?? 'not_dispensed',
            diagnosis: backendDiagnosis.map((d) => d.toString()).toList(),
            medicines: myMeds,
            advice: doc['notes'] ?? '',
            followupDate: doc['followUpDate'] != null ? DateTime.parse(doc['followUpDate']) : null,
          );
        }).toList();

      } else {
        print('Backend error: ${responseData['message']}');
      }

    } catch (e) {
      print('HTTP error fetching prescriptions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  List<Prescription> _getFilteredPrescriptions() {
    switch (_filter) {
      case 'active':
        return _prescriptions.where((p) => p.isActive).toList();
      case 'expired':
        return _prescriptions.where((p) => p.isExpired).toList();
      case 'completed':
        return _prescriptions
            .where((p) => p.pharmacyStatus == 'fully_dispensed')
            .toList();
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
}
