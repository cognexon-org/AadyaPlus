import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the patient is, for distances to clinics and the area shown on
/// Home. Read from the device's GPS — never a placeholder city — and the
/// last known area is remembered so Home has a label straight away.
class LocationProvider with ChangeNotifier {
  static const _labelKey = 'last_location_label';
  static const _cityKey = 'last_location_city';
  static const _pincodeKey = 'last_location_pincode';

  double? _lat;
  double? _lng;
  String? _label;
  String? _city;
  String? _pincode;
  bool _locating = false;
  String? _problem;

  double? get lat => _lat;
  double? get lng => _lng;
  bool get hasPosition => _lat != null && _lng != null;

  /// A short area name, e.g. "Indiranagar, Bengaluru".
  String? get label => _label;
  String? get city => _city;
  String? get pincode => _pincode;
  bool get locating => _locating;

  /// Why the last attempt failed, in plain words.
  String? get problem => _problem;

  LocationProvider() {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _label = prefs.getString(_labelKey);
      _city = prefs.getString(_cityKey);
      _pincode = prefs.getString(_pincodeKey);
      notifyListeners();
    } catch (_) {}
  }

  /// Reads the current position. With [ask] false it only uses permission
  /// already given, so opening Home never pops a dialog by itself.
  Future<void> locate({bool ask = false}) async {
    if (_locating) return;
    _locating = true;
    _problem = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _problem = 'Location is turned off';
        if (ask) await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _problem = 'Location permission is off';
        if (ask) await Geolocator.openAppSettings();
        return;
      }
      if (permission == LocationPermission.denied) {
        _problem = 'Location permission needed';
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _lat = position.latitude;
      _lng = position.longitude;
      notifyListeners();
      await _name(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Location failed: $e');
      _problem ??= 'Couldn’t find your location';
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void debugSet({required String label, double lat = 12.97, double lng = 77.64}) {
    _label = label;
    _lat = lat;
    _lng = lng;
    _problem = null;
    _locating = false;
    notifyListeners();
  }

  Future<void> _name(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) return;
      final p = places.first;
      final area = [p.subLocality, p.locality]
          .where((e) => e != null && e.trim().isNotEmpty)
          .cast<String>()
          .toList();
      _label = area.isNotEmpty
          ? area.join(', ')
          : (p.subAdministrativeArea ?? p.administrativeArea);
      _city = p.locality;
      _pincode = p.postalCode;
      final prefs = await SharedPreferences.getInstance();
      if (_label != null) await prefs.setString(_labelKey, _label!);
      if (_city != null) await prefs.setString(_cityKey, _city!);
      if (_pincode != null) await prefs.setString(_pincodeKey, _pincode!);
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }
  }
}
