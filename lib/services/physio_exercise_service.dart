import 'dart:convert';

import 'api_client.dart' as api;

class PhysioExerciseService {
  PhysioExerciseService._();
  static final PhysioExerciseService instance = PhysioExerciseService._();

  Future<List<Map<String, dynamic>>> getMyPlans() async {
    final response = await api.get(api.apiUri('/physio-exercises/my-plans'));
    final data = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Unable to load physiotherapy plans');
    }
    return (data['plans'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getPlan(String planId) async {
    final response = await api.get(api.apiUri('/physio-exercises/my-plans/$planId'));
    final data = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Unable to load exercise plan');
    }
    return data;
  }

  Future<Map<String, dynamic>> getProgress(String planId) async {
    final response = await api.get(api.apiUri('/physio-exercises/my-plans/$planId/progress'));
    final data = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Unable to load exercise progress');
    }
    return data;
  }

  Future<Map<String, dynamic>> logProgress(
    String planId, {
    required String planItemId,
    int setsCompleted = 0,
    int repsCompleted = 0,
    int durationSec = 0,
    int? painBefore,
    int? painAfter,
    String? perceivedDifficulty,
    String? notes,
  }) async {
    final response = await api.post(
      api.apiUri('/physio-exercises/my-plans/$planId/progress'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'planItemId': planItemId,
        'setsCompleted': setsCompleted,
        'repsCompleted': repsCompleted,
        'durationSec': durationSec,
        if (painBefore != null) 'painBefore': painBefore,
        if (painAfter != null) 'painAfter': painAfter,
        if (perceivedDifficulty != null) 'perceivedDifficulty': perceivedDifficulty,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'completed': true,
      }),
    );
    final data = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception(data['error'] ?? 'Unable to save exercise progress');
    }
    return data;
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final value = jsonDecode(body);
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }
}
