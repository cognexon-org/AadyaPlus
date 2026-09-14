import 'dart:ui';
import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'Aadya Plus';
  static const Color primaryColor = Color(0xFF0284C7); // tailwind sky-600
  static const Color secondaryColor = Color(0xFF0EA5E9); // tailwind sky-500
  static const Color backgroundColor = Color(0xFFF8FAFC); // tailwind slate-50
  static const Color textColor = Color(0xFF0F172A); // tailwind slate-900
  static const Color lightTextColor = Color(0xFF64748B); // tailwind slate-500

  /// Compile-time API configuration.
  ///
  /// Production example:
  /// flutter build apk \\
  ///   --dart-define=AADYA_API_BASE_URL=https://api.example.com/api \\
  ///   --dart-define=AADYA_SOCKET_BASE_URL=https://api.example.com
  ///
  /// Release builds require AADYA_API_BASE_URL. Debug builds retain the old
  /// endpoint only as a developer fallback so existing local workflows continue
  /// to run while teams transition their launch configurations.
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'AADYA_API_BASE_URL',
    defaultValue: '',
  );

  static const String _configuredSocketBaseUrl = String.fromEnvironment(
    'AADYA_SOCKET_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final configured = _stripTrailingSlash(_configuredApiBaseUrl);
    if (configured.isNotEmpty) return configured;
    if (kReleaseMode) {
      throw StateError(
        'AADYA_API_BASE_URL is required for release builds. ' 
        'Pass --dart-define=AADYA_API_BASE_URL=https://<host>/api',
      );
    }
    return 'http://13.48.49.45/api';
  }

  static String get socketBaseUrl {
    final configured = _stripTrailingSlash(_configuredSocketBaseUrl);
    if (configured.isNotEmpty) return configured;

    final apiUri = Uri.parse(baseUrl);
    final path = apiUri.path.endsWith('/api')
        ? apiUri.path.substring(0, apiUri.path.length - 4)
        : apiUri.path;
    return apiUri.replace(path: path.isEmpty ? '/' : path).toString().replaceFirst(RegExp(r'/$'), '');
  }

  static String _stripTrailingSlash(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  // API endpoints
  static String get loginUrl => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get doctorsUrl => '$baseUrl/doctor';
  static String get physiosUrl => '$baseUrl/physio';
  static String get appointmentsUrl => '$baseUrl/appointment';
  static String get medicinesUrl => '$baseUrl/medicine';
  static String get labTestsUrl => '$baseUrl/labtest';
  static String get chatUrl => '$baseUrl/chat';
  static String get pharmacyUrl => '$baseUrl/pharmacy';
  static String get prescriptionsUrl => '$baseUrl/prescription';
  static String get pathologyUrl => '$baseUrl/pathology';
  static String get notificationsUrl => '$baseUrl/notifications';
  static String get paymentsUrl => '$baseUrl/payment';

  // Storage Keys
  // tokenKey is kept stable to support one-time migration from old builds.
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String cartKey = 'cart_items';
  static const String chatKey = 'chat_messages';
  static const String wishlistKey = 'wishlist_items';

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return const Color(0xFF10B981); // Emerald 500
      case 'pending':
        return const Color(0xFFF59E0B); // Amber 500
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEF4444); // Red 500
      case 'completed':
        return const Color(0xFF3B82F6); // Blue 500
      default:
        return const Color(0xFF94A3B8); // Slate 400
    }
  }
}

class Categories {
  static const List<Map<String, dynamic>> items = [
    {'image': 'https://cdn-icons-png.flaticon.com/512/2785/2785501.png', 'title': 'Doctors', 'route': 'doctors'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/883/883356.png', 'title': 'Pharmacy', 'route': 'pharmacy'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/3209/3209121.png', 'title': 'Pathology', 'route': 'pathology'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/2864/2864333.png', 'title': 'Physio', 'route': 'physiotherapy'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/563/563969.png', 'title': 'Prescription', 'route': 'prescriptions'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/2693/2693507.png', 'title': 'Appt.', 'route': 'appointments'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/2738/2738870.png', 'title': 'Medicines', 'route': 'medicines'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/2376/2376100.png', 'title': 'Records', 'route': 'health_records'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/1041/1041916.png', 'title': 'Chat', 'route': 'chat'},
    {'image': 'https://cdn-icons-png.flaticon.com/512/1301/1301474.png', 'title': 'Lab Tests', 'route': 'lab_tests'},
  ];
}
