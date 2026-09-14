import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aadya_plus/models/user.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/services/secure_storage_service.dart';
import 'package:aadya_plus/services/push_notification_service.dart';
import 'package:aadya_plus/utils/constants.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get needsProfileCompletion =>
      _isAuthenticated && _user?.profileCompleted != true;
  String? get error => _error;

  AuthProvider() {
    http.setUnauthorizedHandler(_handleUnauthorized);
    _loadUserData();
  }


  Future<void> _handleUnauthorized() async {
    if (!_isAuthenticated && _token == null) return;
    await _clearLocalSession();
  }

  Future<void> _loadUserData() async {
    _setLoading(true);
    _error = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await SecureStorageService.instance.readToken();
      final userDataString = prefs.getString(AppConstants.userKey);

      if (token == null || token.isEmpty) {
        await _clearLocalSession(notify: false);
        return;
      }

      _token = token;

      // Restore a safe cached identity immediately, then verify it with /auth/me.
      if (userDataString != null) {
        try {
          final cached = User.fromJson(
            Map<String, dynamic>.from(json.decode(userDataString)),
          );
          if (cached.role == 'patient') {
            _user = cached;
            _isAuthenticated = true;
          }
        } catch (e) {
          debugPrint('Ignoring invalid cached user data: $e');
          await prefs.remove(AppConstants.userKey);
        }
      }

      await refreshCurrentUser(clearOnUnauthorized: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshCurrentUser({bool clearOnUnauthorized = true}) async {
    final token = await SecureStorageService.instance.readToken();
    if (token == null || token.isEmpty) {
      await _clearLocalSession();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/me'),
        headers: {'Content-Type': 'application/json'},
      );
      final responseData = _decodeObject(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final backendUser = Map<String, dynamic>.from(responseData['user'] ?? {});
        final parsedUser = User.fromJson(backendUser);
        _ensurePatientRole(parsedUser);
        await _persistSession(token, parsedUser);
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        if (clearOnUnauthorized) {
          await _clearLocalSession();
        }
        return;
      }

      // Keep the cached session for transient server errors.
      debugPrint(
        'Session refresh failed with ${response.statusCode}: '
        '${responseData['error'] ?? responseData['message'] ?? response.body}',
      );
    } catch (e) {
      // Network loss should not destroy a previously valid local session.
      debugPrint('Session refresh network error: $e');
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.post(
        Uri.parse(AppConstants.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = _decodeObject(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final token = responseData['token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Login response did not include an authentication token');
        }

        final backendUser = Map<String, dynamic>.from(responseData['user'] ?? {});
        final parsedUser = User.fromJson(backendUser);
        _ensurePatientRole(parsedUser);
        await _persistSession(token, parsedUser);
      } else {
        throw Exception(
          responseData['error'] ?? responseData['message'] ?? 'Failed to login',
        );
      }
    } catch (error) {
      _error = _cleanError(error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.post(
        Uri.parse(AppConstants.registerUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-registration-source': 'aadya-plus-mobile',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'role': 'patient',
        }),
      );

      final responseData = _decodeObject(response.body);

      if (response.statusCode == 201 && responseData['success'] == true) {
        final token = responseData['token']?.toString();
        if (token == null || token.isEmpty) {
          throw Exception('Registration response did not include a token');
        }

        final backendUser = Map<String, dynamic>.from(responseData['user'] ?? {});
        final parsedUser = User.fromJson(backendUser);
        _ensurePatientRole(parsedUser);
        await _persistSession(token, parsedUser);
      } else {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Failed to register',
        );
      }
    } catch (error) {
      _error = _cleanError(error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completePatientProfile({
    required DateTime dateOfBirth,
    required String gender,
  }) async {
    if (_user == null) throw Exception('No authenticated patient');

    _setLoading(true);
    _error = null;

    try {
      final nameParts = _user!.name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      final firstName = nameParts.isNotEmpty ? nameParts.first : _user!.name;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/complete-profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dateOfBirth': dateOfBirth.toIso8601String(),
          'gender': gender,
          'firstName': firstName,
          if (lastName.isNotEmpty) 'lastName': lastName,
        }),
      );

      final responseData = _decodeObject(response.body);
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Failed to complete patient profile',
        );
      }

      await refreshCurrentUser(clearOnUnauthorized: true);
      if (_user?.profileCompleted != true) {
        throw Exception('Profile was saved but could not be refreshed');
      }
    } catch (error) {
      _error = _cleanError(error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      if (await SecureStorageService.instance.readToken() != null) {
        await PushNotificationService.instance.unregisterAuthenticatedDevice();
        await http.post(
          Uri.parse('${AppConstants.baseUrl}/auth/logout'),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      // Local logout must always succeed even if the network is unavailable.
      debugPrint('Logout API error: $e');
    } finally {
      await _clearLocalSession(notify: false);
      _setLoading(false);
    }
  }

  Future<void> updateProfile(User updatedUser) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/auth/profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': updatedUser.name,
          'phone': updatedUser.phone,
        }),
      );

      final responseData = _decodeObject(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _user = updatedUser.copyWith(
          role: _user?.role ?? 'patient',
          isVerified: _user?.isVerified ?? false,
          profileCompleted: _user?.profileCompleted ?? false,
          profileId: _user?.profileId,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, json.encode(_user!.toJson()));
      } else {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Failed to update profile',
        );
      }
    } catch (error) {
      _error = _cleanError(error);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _persistSession(String token, User user) async {
    _token = token;
    _user = user;
    _isAuthenticated = true;

    await SecureStorageService.instance.writeToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, json.encode(user.toJson()));
    notifyListeners();

    // Do not block login/session restore if push services are temporarily
    // unavailable. The service safely no-ops until Firebase is configured.
    PushNotificationService.instance.syncAuthenticatedDevice();
  }

  Future<void> _clearLocalSession({bool notify = true}) async {
    await SecureStorageService.instance.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);

    _user = null;
    _token = null;
    _isAuthenticated = false;
    if (notify) notifyListeners();
  }

  void _ensurePatientRole(User user) {
    if (user.role != 'patient') {
      throw Exception(
        'This account is registered as ${user.role}. '
        'Please use the AadyaPlus Pro app for professional accounts.',
      );
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'data': decoded};
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
