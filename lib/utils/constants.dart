import 'dart:ui';

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

  static const String _configuredRazorpayKeyId = String.fromEnvironment(
    'AADYA_RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  /// The production backend, used when no AADYA_API_BASE_URL is passed.
  /// Release builds used to throw without the dart-define, which broke every
  /// request in a store build (the pro app shipped with the same bug).
  static const String defaultApiBaseUrl = 'http://16.176.130.55/api';

  static String get baseUrl {
    final configured = _stripTrailingSlash(_configuredApiBaseUrl);
    return configured.isNotEmpty ? configured : defaultApiBaseUrl;
  }

  static String get socketBaseUrl {
    final configured = _stripTrailingSlash(_configuredSocketBaseUrl);
    if (configured.isNotEmpty) return configured;

    final apiUri = Uri.parse(baseUrl);
    final path = apiUri.path.endsWith('/api')
        ? apiUri.path.substring(0, apiUri.path.length - 4)
        : apiUri.path;
    return apiUri
        .replace(path: path.isEmpty ? '/' : path)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }

  static String get razorpayKeyId => _configuredRazorpayKeyId.trim();

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
  static String get consultationsUrl => '$baseUrl/consultations';
  static String get ePharmacyUrl => '$baseUrl/epharmacy';
  static String get diagnosticsUrl => '$baseUrl/diagnostics';

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
