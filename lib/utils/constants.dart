import 'dart:ui';

class AppConstants {
  static const String appName = 'Aadya Plus';
  static const Color primaryColor = Color(0xFF0284C7); // tailwind sky-600
  static const Color secondaryColor = Color(0xFF0EA5E9); // tailwind sky-500
  static const Color backgroundColor = Color(0xFFF8FAFC); // tailwind slate-50
  static const Color textColor = Color(0xFF0F172A); // tailwind slate-900
  static const Color lightTextColor = Color(0xFF64748B); // tailwind slate-500

  // API endpoints
  static const String baseUrl = 'http://13.48.49.45/api';
  static const String loginUrl = '$baseUrl/auth/login';
  static const String registerUrl = '$baseUrl/auth/register';
  static const String doctorsUrl = '$baseUrl/doctor';
  static const String physiosUrl = '$baseUrl/physio';
  static const String appointmentsUrl = '$baseUrl/appointment';
  static const String medicinesUrl = '$baseUrl/medicine';
  static const String labTestsUrl = '$baseUrl/labtest';
  static const String chatUrl = '$baseUrl/chat';
  static const String pharmacyUrl = '$baseUrl/pharmacy';
  static const String prescriptionsUrl = '$baseUrl/prescription';
  static const String pathologyUrl = '$baseUrl/pathology';
  static const String notificationsUrl = '$baseUrl/notifications';
  static const String paymentsUrl = '$baseUrl/payment';

  // Shared Preferences Keys
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

