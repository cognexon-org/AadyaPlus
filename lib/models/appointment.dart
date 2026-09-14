class Appointment {
  final String id;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final String hospital;
  final String patientName;
  final DateTime dateTime;
  final String status;
  final double consultationFee;
  final double totalAmount;
  final String paymentStatus;
  final String appointmentType;
  final String? symptoms;
  final DateTime createdAt;

  // Compatibility-only: Patch 4 no longer exposes this for secure video join.
  final String? meetingLink;
  final String? startTime;
  final String? reason;
  final String? prescriptionId;
  final String? consultationSessionId;
  final String professionalType;
  final int duration;

  Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.hospital,
    required this.patientName,
    required this.dateTime,
    required this.status,
    required this.consultationFee,
    double? totalAmount,
    this.paymentStatus = 'pending',
    required this.appointmentType,
    this.symptoms,
    required this.createdAt,
    this.meetingLink,
    this.startTime,
    this.reason,
    this.prescriptionId,
    this.consultationSessionId,
    this.professionalType = 'doctor',
    this.duration = 30,
  }) : totalAmount = totalAmount ?? consultationFee;

  bool get isVideo => appointmentType.toLowerCase() == 'video';
  bool get isPaid => paymentStatus.toLowerCase() == 'paid' || totalAmount <= 0;
  bool get paymentRequired => isVideo && totalAmount > 0 && !isPaid;
  bool get isTerminal => const ['completed', 'cancelled', 'rejected', 'no_show']
      .contains(status.toLowerCase());

  Appointment copyWith({
    String? status,
    String? paymentStatus,
    String? prescriptionId,
    String? consultationSessionId,
  }) {
    return Appointment(
      id: id,
      doctorId: doctorId,
      doctorName: doctorName,
      specialty: specialty,
      hospital: hospital,
      patientName: patientName,
      dateTime: dateTime,
      status: status ?? this.status,
      consultationFee: consultationFee,
      totalAmount: totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      appointmentType: appointmentType,
      symptoms: symptoms,
      createdAt: createdAt,
      meetingLink: meetingLink,
      startTime: startTime,
      reason: reason,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      consultationSessionId: consultationSessionId ?? this.consultationSessionId,
      professionalType: professionalType,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'hospital': hospital,
      'patientName': patientName,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'consultationFee': consultationFee,
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus,
      'appointmentType': appointmentType,
      'symptoms': symptoms,
      'createdAt': createdAt.toIso8601String(),
      'startTime': startTime,
      'reason': reason,
      'prescriptionId': prescriptionId,
      'consultationSessionId': consultationSessionId,
      'professionalType': professionalType,
      'duration': duration,
    };
  }
}
