import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aadya_plus/models/user.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final userDataString = prefs.getString(AppConstants.userKey);

    if (token != null && userDataString != null) {
      try {
        _token = token;
        final userData = json.decode(userDataString) as Map<String, dynamic>;
        _user = User.fromJson(userData);
        _isAuthenticated = true;
      } catch (e) {
        print('Error parsing user data: $e');
        await prefs.remove(AppConstants.tokenKey);
        await prefs.remove(AppConstants.userKey);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(AppConstants.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _token = responseData['token'];
        
        // Map backend user object to our Flutter model
        final backendUser = responseData['user'];
        _user = User(
          id: backendUser['id'] ?? backendUser['_id'] ?? '',
          profileId: backendUser['profileId'],
          name: backendUser['name'] ?? '',
          email: backendUser['email'] ?? '',
          phone: backendUser['phone'] ?? '',
          createdAt: backendUser['createdAt'] != null ? DateTime.tryParse(backendUser['createdAt']) ?? DateTime.now() : DateTime.now(),
        );
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, _token!);
        await prefs.setString(AppConstants.userKey, json.encode(_user!.toJson()));
      } else {
        throw Exception(responseData['error'] ?? 'Failed to login');
      }
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password, String phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(AppConstants.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'role': 'patient', // Default role for users from app
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 && responseData['success'] == true) {
        _token = responseData['token'];
        
        final backendUser = responseData['user'];
        _user = User(
          id: backendUser['id'] ?? backendUser['_id'] ?? '',
          profileId: backendUser['profileId'],
          name: backendUser['name'] ?? '',
          email: backendUser['email'] ?? '',
          phone: backendUser['phone'] ?? '',
          createdAt: backendUser['createdAt'] != null ? DateTime.tryParse(backendUser['createdAt']) ?? DateTime.now() : DateTime.now(),
        );
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, _token!);
        await prefs.setString(AppConstants.userKey, json.encode(_user!.toJson()));
      } else {
        throw Exception(responseData['error'] ?? 'Failed to register');
      }
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null) {
        // Optionlally call backend logout if it exists
        await http.post(
          Uri.parse('${AppConstants.baseUrl}/auth/logout'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        );
      }
    } catch (e) {
      print('Logout API error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);

    _user = null;
    _token = null;
    _isAuthenticated = false;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile(User updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/auth/profile'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': updatedUser.name,
          'phone': updatedUser.phone,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _user = updatedUser;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, json.encode(_user!.toJson()));
      } else {
         throw Exception(responseData['error'] ?? 'Failed to update profile');
      }
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }
}