import 'dart:convert';

import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:intl/intl.dart' show DateFormat;

class ProfessionalApiException implements Exception {
  final String message;
  final int statusCode;
  const ProfessionalApiException(this.message, {required this.statusCode});
  @override
  String toString() => message;
}

/// A doctor's or physio's full public profile, with what patients said.
class ProfessionalProfile {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> reviews;
  final Map<int, int> ratingDistribution;

  /// The first bookable slot, e.g. {date: 2026-10-27, startTime: 10:30}.
  final Map<String, dynamic>? nextAvailable;
  const ProfessionalProfile({
    required this.profile,
    required this.reviews,
    required this.ratingDistribution,
    this.nextAvailable,
  });

  String get about => (profile['about'] ?? '').toString().trim();
  List<String> get services => _strings(profile['services']);
  List<String> get awards => _strings(profile['awards']);
  List<String> get languages => _strings(profile['languages']);
  List<String> get servesAreas => _strings(profile['servesAreas']);

  static List<String> _strings(dynamic v) => v is List
      ? v
            .map((e) => e is Map ? (e['name'] ?? e['title'] ?? '').toString() : e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
      : const [];
}

/// One day of a professional's slots for one visit type.
class DayAvailability {
  final bool isAvailable;
  final String? reason;
  final List<Map<String, dynamic>> slots;
  const DayAvailability({required this.isAvailable, this.reason, required this.slots});
}

/// The public doctor and physio endpoints the booking flow needs.
class ProfessionalService {
  ProfessionalService._();
  static final ProfessionalService instance = ProfessionalService._();

  static String _base(String type) => type == 'physio' ? '/physio' : '/doctor';

  Future<ProfessionalProfile> profile(String id, String type) async {
    final response = await http.get(http.apiUri('${_base(type)}/$id'));
    final data = _decode(response.body);
    _assert(response.statusCode, data, 'Couldn’t load this profile');
    final profile = Map<String, dynamic>.from(
      (type == 'physio' ? data['physio'] : data['doctor']) ?? const {},
    );
    var reviews = _list(data['reviews']);
    final distribution = <int, int>{};
    final raw = data['ratingDistribution'];
    if (raw is Map) {
      raw.forEach((k, v) => distribution[int.tryParse('$k') ?? 0] = (v as num?)?.toInt() ?? 0);
    }
    if (type == 'physio') {
      // The physio profile carries no reviews; the feedback list does.
      try {
        final r = await http.get(http.apiUri('/feedback', queryParameters: {
          'professionalId': id,
          'professionalType': 'physio',
          'limit': 10,
        }));
        final fd = _decode(r.body);
        if (r.statusCode == 200 && fd['success'] == true) {
          reviews = _list(fd['feedbacks']);
          final stats = fd['stats'];
          if (stats is Map && stats['distribution'] is Map) {
            (stats['distribution'] as Map).forEach(
              (k, v) => distribution[int.tryParse('$k') ?? 0] = (v as num?)?.toInt() ?? 0,
            );
          }
        }
      } catch (_) {}
    }
    final next = profile['nextAvailable'];
    return ProfessionalProfile(
      profile: profile,
      reviews: reviews,
      ratingDistribution: distribution,
      nextAvailable: next is Map ? Map<String, dynamic>.from(next) : null,
    );
  }

  Future<DayAvailability> availability({
    required String id,
    required String type,
    required DateTime date,
    required String visit,
  }) async {
    final response = await http.get(http.apiUri('${_base(type)}/$id/availability', queryParameters: {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'type': visit,
    }));
    final data = _decode(response.body);
    _assert(response.statusCode, data, 'Couldn’t load the available times');
    final slots = _list(data['availableSlots'])
        .where((s) => s['isAvailable'] != false)
        .toList();
    return DayAvailability(
      isAvailable: data['isAvailable'] != false && slots.isNotEmpty,
      reason: data['reason']?.toString(),
      slots: slots,
    );
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return {};
    final decoded = json.decode(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {'data': decoded};
  }

  static void _assert(int status, Map<String, dynamic> data, String fallback) {
    if (status >= 200 && status < 300 && data['success'] != false) return;
    throw ProfessionalApiException(
      (data['error'] ?? data['message'] ?? fallback).toString(),
      statusCode: status,
    );
  }

  static List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
}
