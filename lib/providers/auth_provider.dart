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
  bool _isRestoring = true;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;

  /// True only while the saved session is first read at launch. The app
  /// shows its splash for this — not for sign-in, which used to swap the
  /// login screen for a spinner and lose its error message.
  bool get isRestoring => _isRestoring;
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

      if (_isAuthenticated) {
        // A cached account opens straight away; the server check runs in
        // the background so a slow network never holds the app on launch.
        _finishRestoring();
        refreshCurrentUser(clearOnUnauthorized: true);
      } else {
        await refreshCurrentUser(clearOnUnauthorized: true);
      }
    } finally {
      _setLoading(false);
      _finishRestoring();
    }
  }

  void _finishRestoring() {
    if (!_isRestoring) return;
    _isRestoring = false;
    notifyListeners();
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
    String phone, {
    String? verificationToken,
  }) async {
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
          'verificationToken': ?verificationToken,
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

  /// Texts a one-time code to [phone]. The reply says whether the number
  /// belongs to an account (sign in) or is new (sign up).
  Future<OtpChallenge> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );
    final data = _decodeObject(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Couldn’t send the code');
    }
    return OtpChallenge(
      phone: (data['phone'] ?? phone).toString(),
      isNewAccount: data['purpose'] == 'signup',
      resendAfter: Duration(
        seconds: (data['resendAfterSeconds'] as num?)?.toInt() ?? 30,
      ),
    );
  }

  /// Checks the code. Signs an existing patient straight in and returns
  /// null; for a new number returns the single-use token that [register]
  /// redeems to create the account with that verified phone.
  Future<String?> verifyOtp(String phone, String code) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone, 'code': code}),
    );
    final data = _decodeObject(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'That code didn’t work');
    }
    if (data['registered'] == false) {
      return data['verificationToken']?.toString();
    }
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Sign-in response did not include a token');
    }
    final parsedUser = User.fromJson(Map<String, dynamic>.from(data['user'] ?? {}));
    _ensurePatientRole(parsedUser);
    await _persistSession(token, parsedUser);
    return null;
  }

  /// Emails a reset link. The server answers the same whether or not the
  /// address has an account.
  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    final data = _decodeObject(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Couldn’t send the reset link');
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

  /// Renames the account (the phone is the sign-in identity and changes
  /// only through a new OTP; the email is fixed once verified).
  Future<void> updateName(String name) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/auth/profile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name.trim()}),
    );
    final data = _decodeObject(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Couldn’t update your name');
    }
    await _saveUser(_user!.copyWith(name: name.trim()));
  }

  Future<void> changePassword(String current, String next) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/auth/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'currentPassword': current, 'newPassword': next}),
    );
    final data = _decodeObject(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Couldn’t change your password');
    }
    // A password change issues a new token on some servers; keep the session.
    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      _token = token;
      await SecureStorageService.instance.writeToken(token);
    }
  }

  /// Saves which channels the patient wants to hear on.
  Future<void> updateNotificationChannels(Map<String, bool> channels) async {
    final before = _user;
    final merged = {
      ...?(_user?.preferences),
      'notifications': {
        ...?(_user?.preferences['notifications'] as Map?),
        ...channels,
      },
    };
    if (_user != null) await _saveUser(_user!.copyWith(preferences: merged));
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/auth/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'notifications': channels}),
      );
      final data = _decodeObject(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['error'] ?? 'Couldn’t save that setting');
      }
    } catch (e) {
      if (before != null) await _saveUser(before);
      rethrow;
    }
  }

  Future<void> _saveUser(User user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, json.encode(user.toJson()));
    notifyListeners();
  }

  @visibleForTesting
  void debugSignIn(User user) {
    _user = user;
    _isAuthenticated = true;
    _isRestoring = false;
    notifyListeners();
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

/// A code sent by [AuthProvider.sendOtp].
class OtpChallenge {
  final String phone;
  final bool isNewAccount;
  final Duration resendAfter;
  const OtpChallenge({
    required this.phone,
    required this.isNewAccount,
    required this.resendAfter,
  });
}
