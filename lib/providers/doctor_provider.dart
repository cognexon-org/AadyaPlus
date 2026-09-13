import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aadya_plus/models/doctor.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorProvider with ChangeNotifier {
  List<Doctor> _doctors = [];
  List<Doctor> _filteredDoctors = [];
  String _selectedSpecialty = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  // Location state
  double? _userLat;
  double? _userLng;
  String _sortBy = 'rating'; // rating, nearby, fee_low, fee_high, experience

  List<Doctor> get doctors => _filteredDoctors;
  List<Doctor> get allDoctors => _doctors;
  String get selectedSpecialty => _selectedSpecialty;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double? get userLat => _userLat;
  double? get userLng => _userLng;
  String get sortBy => _sortBy;
  bool get hasLocation => _userLat != null && _userLng != null;

  DoctorProvider() {
    _loadDoctors();
  }

  /// Haversine formula - matches the web version exactly
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Set user location and recalculate distances
  void setUserLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _calculateDistances();
    _applyFilters();
    notifyListeners();
  }

  /// Calculates distance for all doctors from user location
  void _calculateDistances() {
    if (_userLat == null || _userLng == null) return;
    for (final doctor in _doctors) {
      if (doctor.latitude != null && doctor.longitude != null) {
        doctor.distance = _calculateDistance(
          _userLat!, _userLng!,
          doctor.latitude!, doctor.longitude!,
        );
      }
    }
  }

  /// Parse a single professional from API JSON
  Doctor _parseProfessional(Map<String, dynamic> doc, String type) {
    // Extract clinic location coordinates [lng, lat]
    double? lat;
    double? lng;
    if (doc['clinicAddress'] != null && doc['clinicAddress']['location'] != null) {
      final coords = doc['clinicAddress']['location']['coordinates'];
      if (coords != null && coords is List && coords.length == 2) {
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      }
    }

    return Doctor(
      id: doc['_id']?.toString() ?? '',
      name: doc['name']?.toString() ?? (type == 'physio' ? 'Unknown Physiotherapist' : 'Unknown'),
      specialty: (doc['specialization'] != null && doc['specialization'] is List && (doc['specialization'] as List).isNotEmpty)
          ? doc['specialization'][0].toString()
          : (type == 'physio' ? 'Physiotherapist' : 'General'),
      hospital: doc['clinicAddress'] != null ? doc['clinicAddress']['city']?.toString() ?? 'Unknown' : 'Unknown',
      rating: (doc['averageRating'] ?? 0).toDouble(),
      reviews: doc['totalReviews'] ?? 0,
      consultationFee: (doc['consultationFee'] ?? 0).toDouble(),
      experience: doc['experienceYears'] ?? 0,
      imageUrl: doc['profileImage']?.toString() ??
          'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=200&h=200&fit=crop&q=80',
      description: doc['about']?.toString() ?? 'No description available',
      languages: doc['languages'] != null ? (doc['languages'] as List).map((e) => e.toString()).toList() : ['English'],
      availability: {},
      videoCallFee: (doc['videoCallFee'] ?? 0).toDouble(),
      homeVisitFee: (doc['homeVisitFee'] ?? 0).toDouble(),
      services: doc['services'] != null ? (doc['services'] as List).map((e) => e).toList() : [],
      verificationStatus: doc['verificationStatus']?.toString() ?? 'pending',
      gender: doc['gender']?.toString() ?? '',
      totalConsultations: doc['totalConsultations'] ?? 0,
      professionalType: type,
      latitude: lat,
      longitude: lng,
    );
  }

  Future<void> _loadDoctors() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      // Fetch both doctors and physios in parallel
      final results = await Future.wait([
        http.get(
          Uri.parse(AppConstants.doctorsUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
        http.get(
          Uri.parse(AppConstants.physiosUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      ]);

      final responseData = json.decode(results[0].body);
      final physioData = json.decode(results[1].body);

      List<Doctor> loadedDoctors = [];

      if (results[0].statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> doctorDocs = responseData['doctors'] ?? [];
        loadedDoctors.addAll(doctorDocs.map((doc) => _parseProfessional(doc, 'doctor')));
      } else {
        _error = responseData['error'] ?? 'Failed to load doctors';
      }

      if (results[1].statusCode == 200 && physioData['success'] == true) {
        final List<dynamic> physioDocs = physioData['physios'] ?? [];
        loadedDoctors.addAll(physioDocs.map((doc) => _parseProfessional(doc, 'physio')));
      }

      _doctors = loadedDoctors;
      
      // Calculate distances if we already have user location
      _calculateDistances();
      
      _filteredDoctors = _doctors;
      _applyFilters();
    } catch (e) {
      _error = 'Network error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Reload doctors from API
  Future<void> refreshDoctors() async {
    await _loadDoctors();
  }

  /// Change sort mode
  void setSortBy(String sort) {
    _sortBy = sort;
    _applyFilters();
    notifyListeners();
  }

  /// Apply all filters and sorting
  void _applyFilters() {
    var result = List<Doctor>.from(_doctors);

    // Specialty filter
    if (_selectedSpecialty != 'All') {
      result = result.where((d) => d.specialty == _selectedSpecialty).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((d) =>
        d.name.toLowerCase().contains(q) ||
        d.specialty.toLowerCase().contains(q) ||
        d.hospital.toLowerCase().contains(q)
      ).toList();
    }

    // Sorting
    switch (_sortBy) {
      case 'nearby':
        if (hasLocation) {
          result.sort((a, b) {
            final ad = a.distance ?? double.infinity;
            final bd = b.distance ?? double.infinity;
            return ad.compareTo(bd);
          });
        }
        break;
      case 'fee_low':
        result.sort((a, b) => a.consultationFee.compareTo(b.consultationFee));
        break;
      case 'fee_high':
        result.sort((a, b) => b.consultationFee.compareTo(a.consultationFee));
        break;
      case 'experience':
        result.sort((a, b) => b.experience.compareTo(a.experience));
        break;
      default: // rating
        result.sort((a, b) => b.rating.compareTo(a.rating));
    }

    _filteredDoctors = result;
  }

  void filterDoctors(String specialty) {
    _selectedSpecialty = specialty;
    _applyFilters();
    notifyListeners();
  }

  void searchDoctors(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  Doctor getDoctorById(String id) {
    return _doctors.firstWhere((doctor) => doctor.id == id);
  }

  List<String> getSpecialties() {
    final specialties = _doctors
        .map((doctor) => doctor.specialty)
        .toSet()
        .toList();
    return ['All', ...specialties];
  }
}
