import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/models/doctor.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';

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

  static bool _typeEnabled(Map<String, dynamic> doc, String flag, double fee) {
    // Mirrors the backend's getDoctorTypeEnabled: an unset flag means
    // "offered when it has a fee".
    final v = doc[flag];
    if (v is bool) return v;
    return fee > 0;
  }

  /// Parse a single professional from API JSON
  Doctor _parseProfessional(Map<String, dynamic> doc, String type) {
    final address = doc['clinicAddress'] is Map
        ? Map<String, dynamic>.from(doc['clinicAddress'])
        : <String, dynamic>{};
    // Clinic coordinates are [lng, lat]; [0, 0] is the schema default, not a place.
    double? lat;
    double? lng;
    final coords = address['location'] is Map ? address['location']['coordinates'] : null;
    if (coords is List && coords.length == 2) {
      lng = (coords[0] as num?)?.toDouble();
      lat = (coords[1] as num?)?.toDouble();
      if (lat == 0 && lng == 0) lat = lng = null;
    }
    final specs = doc['specialization'] is List
        ? (doc['specialization'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final quals = doc['qualifications'] is List
        ? (doc['qualifications'] as List)
            .map((q) => q is Map ? (q['degree'] ?? '').toString() : q.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
        : <String>[];
    final clinicFee = ((doc['consultationFee'] ?? 0) as num).toDouble();
    final videoFee = ((doc['videoCallFee'] ?? 0) as num).toDouble();
    final homeFee = ((doc['homeVisitFee'] ?? 0) as num).toDouble();
    final city = (address['city'] ?? '').toString();
    final line = [address['address'], address['locality'], address['city']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(', ');

    return Doctor(
      id: doc['_id']?.toString() ?? '',
      name: doc['name']?.toString() ?? (type == 'physio' ? 'Physiotherapist' : 'Doctor'),
      specialty: specs.isNotEmpty ? specs.first : (type == 'physio' ? 'Physiotherapist' : 'General physician'),
      specialties: specs,
      hospital: city,
      clinicName: (doc['clinicName'] ?? '').toString(),
      clinicAddress: line,
      qualifications: quals,
      rating: ((doc['averageRating'] ?? 0) as num).toDouble(),
      reviews: ((doc['totalReviews'] ?? 0) as num).toInt(),
      consultationFee: clinicFee,
      experience: ((doc['experienceYears'] ?? 0) as num).toInt(),
      imageUrl: doc['profileImage']?.toString() ?? '',
      description: doc['about']?.toString() ?? '',
      languages: doc['languages'] is List ? (doc['languages'] as List).map((e) => e.toString()).toList() : const [],
      availability: {},
      videoCallFee: videoFee,
      homeVisitFee: homeFee,
      clinicEnabled: doc['clinicConsultationEnabled'] != false,
      videoEnabled: _typeEnabled(doc, 'teleconsultationEnabled', videoFee),
      homeEnabled: _typeEnabled(doc, 'homeVisitEnabled', homeFee),
      services: doc['services'] is List ? List<dynamic>.from(doc['services']) : const [],
      verificationStatus: doc['verificationStatus']?.toString() ?? 'pending',
      gender: doc['gender']?.toString() ?? '',
      totalConsultations: ((doc['totalConsultations'] ?? 0) as num).toInt(),
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
      final token = await SecureStorageService.instance.readToken();

      // Fetch both doctors and physios in parallel
      final results = await Future.wait([
        http.get(
          Uri.parse('${AppConstants.doctorsUrl}?limit=50'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
        http.get(
          Uri.parse('${AppConstants.physiosUrl}?limit=100'),
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
      _error = 'Couldn’t load doctors. Check your connection and try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fills the directory without the network, for previews and tests.
  @visibleForTesting
  void debugSeed(List<Doctor> doctors) {
    _doctors = doctors;
    _isLoading = false;
    _error = null;
    _calculateDistances();
    _applyFilters();
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

  Doctor getDoctorById(String id) => findById(id)!;

  Doctor? findById(String id) {
    for (final d in _doctors) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// A filtered, sorted view of the directory that leaves the shared
  /// filter state alone, so one screen's search never leaks into another.
  List<Doctor> query({
    String? type,
    String? visit, // clinic | video | home
    String specialty = 'All',
    String search = '',
    String sort = 'rating',
  }) {
    var result = _doctors.where((d) {
      if (type != null && d.professionalType != type) return false;
      if (visit == 'video' && !d.videoEnabled) return false;
      if (visit == 'home' && !d.homeEnabled) return false;
      if (visit == 'clinic' && !d.clinicEnabled) return false;
      if (specialty != 'All' && !d.specialties.contains(specialty) && d.specialty != specialty) {
        return false;
      }
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        final hay = [d.name, d.specialty, ...d.specialties, d.hospital, d.clinicName].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    int byRating(Doctor a, Doctor b) {
      final r = b.rating.compareTo(a.rating);
      return r != 0 ? r : b.reviews.compareTo(a.reviews);
    }
    switch (sort) {
      case 'nearby':
        result.sort((a, b) => (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity));
      case 'fee_low':
        result.sort((a, b) => a.fromFee.compareTo(b.fromFee));
      case 'experience':
        result.sort((a, b) => b.experience.compareTo(a.experience));
      default:
        result.sort(byRating);
    }
    return result;
  }

  /// Every specialty in the directory for [type], most common first.
  List<String> specialtiesFor(String? type) {
    final counts = <String, int>{};
    for (final d in _doctors) {
      if (type != null && d.professionalType != type) continue;
      for (final s in d.specialties.isEmpty ? [d.specialty] : d.specialties) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    final list = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return list;
  }

  List<String> getSpecialties() {
    final specialties = _doctors
        .map((doctor) => doctor.specialty)
        .toSet()
        .toList();
    return ['All', ...specialties];
  }
}
