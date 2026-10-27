import 'dart:convert';

import 'package:aadya_plus/services/api_client.dart' as http;

/// Reviews of completed visits.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  /// The appointment ids the patient has already reviewed.
  Future<Set<String>> reviewedAppointmentIds() async {
    final response = await http.get(http.apiUri('/feedback/my'));
    final data = _decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) return {};
    final list = data['feedbacks'] is List ? data['feedbacks'] as List : const [];
    return list
        .whereType<Map>()
        .map((f) {
          final a = f['appointmentId'];
          return (a is Map ? a['_id'] : a)?.toString() ?? '';
        })
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> submit({
    required String appointmentId,
    required int rating,
    String comments = '',
    bool wouldRecommend = true,
    List<String> strengths = const [],
    bool anonymous = false,
  }) async {
    final response = await http.post(
      http.apiUri('/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'appointmentId': appointmentId,
        'overallRating': rating,
        'comments': comments,
        'wouldRecommend': wouldRecommend,
        'strengths': strengths,
        'isAnonymous': anonymous,
      }),
    );
    final data = _decode(response.body);
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? data['error'] ?? 'Couldn’t send your review');
    }
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return {};
    final d = json.decode(body);
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }
}
