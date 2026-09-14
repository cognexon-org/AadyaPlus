import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/models/lab_test.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';

class LabTestProvider with ChangeNotifier {
  List<LabTest> _labTests = [];
  List<LabTest> _bookedTests = [];
  bool _isLoading = false;
  String? _error;

  List<LabTest> get labTests => _labTests;
  List<LabTest> get bookedTests => _bookedTests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  LabTestProvider() {
    loadLabTests();
  }

  Future<void> loadLabTests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await SecureStorageService.instance.readToken();
      
      final response = await http.get(
        Uri.parse(AppConstants.labTestsUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> tests = responseData['data'] ?? responseData['labTests'] ?? [];
        
        _labTests = tests.map((doc) {
          return LabTest(
            id: doc['_id'] ?? '',
            name: doc['testName'] ?? 'Unknown Test',
            description: doc['description'] ?? '',
            price: doc['price']?.toDouble() ?? 0.0,
            discountPrice: doc['discountPrice']?.toDouble() ?? (doc['price']?.toDouble() ?? 0.0),
            preparation: doc['preparation'] ?? 'No special preparation',
            reportTime: doc['turnAroundTime'] ?? '24 hours',
            parameters: doc['parameters'] != null ? List<String>.from(doc['parameters'].map((p) => p['name'] ?? '')) : [],
            fastingRequired: doc['fastingRequired'] ?? false,
          );
        }).toList();
      } else {
        _error = responseData['message'] ?? 'Failed to load lab tests';
      }
    } catch (e) {
      _error = 'Network error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> bookLabTest(LabTest test, DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
        // Implement real booking when backend endpoint is ready
        // await http.post(...)
        await Future.delayed(const Duration(seconds: 1));
        _bookedTests.add(test);
    } catch (e) {
        _error = 'Booking error: $e';
        throw e;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  List<LabTest> searchLabTests(String query) {
    if (query.isEmpty) return _labTests;
    return _labTests
        .where((test) =>
            test.name.toLowerCase().contains(query.toLowerCase()) ||
            test.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}