import 'dart:convert';

import 'package:aadya_plus/models/consultation_session.dart';
import 'package:aadya_plus/services/api_client.dart' as http;

class ConsultationApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  const ConsultationApiException(
    this.message, {
    required this.statusCode,
    this.code,
  });

  @override
  String toString() => message;
}

class ConsultationService {
  ConsultationService._();
  static final ConsultationService instance = ConsultationService._();

  Future<ConsultationSnapshot> getByAppointment(String appointmentId) async {
    final response = await http.get(
      http.apiUri('/consultations/appointment/$appointmentId'),
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);
    return ConsultationSnapshot.fromJson(data);
  }

  Future<ConsultationSessionState> checkIn(
    String appointmentId, {
    required bool teleconsultationAccepted,
  }) async {
    final response = await http.post(
      http.apiUri('/consultations/appointment/$appointmentId/check-in'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'teleconsultationAccepted': teleconsultationAccepted,
        'privacyNoticeVersion': 'mobile-v1',
      }),
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);
    return ConsultationSessionState.fromJson(
      Map<String, dynamic>.from(data['session'] ?? const {}),
    );
  }

  Future<ConsultationJoinResult> join(String appointmentId) async {
    final response = await http.post(
      http.apiUri('/consultations/appointment/$appointmentId/join'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);

    final joinUrl = (data['joinUrl'] ?? '').toString();
    if (joinUrl.isEmpty) {
      throw const ConsultationApiException(
        'The video room is not available yet.',
        statusCode: 500,
      );
    }

    return ConsultationJoinResult(
      joinUrl: joinUrl,
      provider: (data['provider'] ?? 'jitsi').toString(),
      session: ConsultationSessionState.fromJson(
        Map<String, dynamic>.from(data['session'] ?? const {}),
      ),
    );
  }

  Future<void> leave(String appointmentId) async {
    final response = await http.post(
      http.apiUri('/consultations/appointment/$appointmentId/leave'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _decode(response.body);
    _assertSuccess(response.statusCode, data);
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  void _assertSuccess(int statusCode, Map<String, dynamic> data) {
    if (statusCode >= 200 && statusCode < 300 && data['success'] == true) return;
    throw ConsultationApiException(
      (data['error'] ?? data['message'] ?? 'Consultation request failed').toString(),
      statusCode: statusCode,
      code: data['code']?.toString(),
    );
  }
}
