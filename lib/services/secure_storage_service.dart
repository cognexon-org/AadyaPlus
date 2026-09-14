import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aadya_plus/utils/constants.dart';

/// Stores authentication credentials in the platform secure store.
///
/// Existing installs may still have a JWT in SharedPreferences. The first read
/// migrates that value into Android Keystore / iOS Keychain-backed storage and
/// removes the legacy plaintext preference.
class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<String?> readToken() async {
    final secureToken = await _storage.read(key: AppConstants.tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // One-time migration from pre-U1 builds.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(AppConstants.tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _storage.write(key: AppConstants.tokenKey, value: legacyToken);
      await prefs.remove(AppConstants.tokenKey);
      return legacyToken;
    }

    return null;
  }

  Future<void> writeToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }
}
