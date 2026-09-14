class ConsultationSessionState {
  final String id;
  final String appointmentId;
  final String status;
  final String provider;
  final String consultationType;
  final DateTime? patientCheckedInAt;
  final DateTime? professionalCheckedInAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? scheduledAt;
  final DateTime? joinOpensAt;
  final DateTime? joinClosesAt;
  final bool paymentRequired;
  final bool canCheckIn;
  final bool canJoin;
  final bool consentAccepted;
  final Map<String, dynamic>? clinicalSummary;

  const ConsultationSessionState({
    required this.id,
    required this.appointmentId,
    required this.status,
    required this.provider,
    required this.consultationType,
    this.patientCheckedInAt,
    this.professionalCheckedInAt,
    this.startedAt,
    this.endedAt,
    this.scheduledAt,
    this.joinOpensAt,
    this.joinClosesAt,
    this.paymentRequired = false,
    this.canCheckIn = false,
    this.canJoin = false,
    this.consentAccepted = false,
    this.clinicalSummary,
  });

  bool get isCheckedIn => patientCheckedInAt != null;
  bool get isEnded => status == 'ended' || status == 'cancelled' || status == 'no_show';
  bool get isInProgress => status == 'in_progress';

  factory ConsultationSessionState.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    final consent = json['consent'];
    return ConsultationSessionState(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? '').toString(),
      status: (json['status'] ?? 'scheduled').toString(),
      provider: (json['provider'] ?? 'in_person').toString(),
      consultationType: (json['consultationType'] ?? 'clinic').toString(),
      patientCheckedInAt: parseDate(json['patientCheckedInAt']),
      professionalCheckedInAt: parseDate(json['professionalCheckedInAt']),
      startedAt: parseDate(json['startedAt']),
      endedAt: parseDate(json['endedAt']),
      scheduledAt: parseDate(json['scheduledAt']),
      joinOpensAt: parseDate(json['joinOpensAt']),
      joinClosesAt: parseDate(json['joinClosesAt']),
      paymentRequired: json['paymentRequired'] == true,
      canCheckIn: json['canCheckIn'] == true,
      canJoin: json['canJoin'] == true,
      consentAccepted: consent is Map && consent['teleconsultationAccepted'] == true,
      clinicalSummary: json['clinicalSummary'] is Map
          ? Map<String, dynamic>.from(json['clinicalSummary'])
          : null,
    );
  }
}

class ConsultationSnapshot {
  final ConsultationSessionState session;
  final Map<String, dynamic> appointment;

  const ConsultationSnapshot({
    required this.session,
    required this.appointment,
  });

  factory ConsultationSnapshot.fromJson(Map<String, dynamic> json) {
    return ConsultationSnapshot(
      session: ConsultationSessionState.fromJson(
        Map<String, dynamic>.from(json['session'] ?? const {}),
      ),
      appointment: Map<String, dynamic>.from(json['appointment'] ?? const {}),
    );
  }
}

class ConsultationJoinResult {
  final String joinUrl;
  final String provider;
  final ConsultationSessionState session;

  const ConsultationJoinResult({
    required this.joinUrl,
    required this.provider,
    required this.session,
  });
}
