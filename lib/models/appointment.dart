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
  final String appointmentType;
  final String? symptoms;
  final DateTime createdAt;
  
  // New fields matching web version
  final String? meetingLink;
  final String? startTime;       // Raw HH:MM from backend
  final String? reason;
  final String? prescriptionId;
  final String professionalType; // 'doctor' or 'physio'
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
    required this.appointmentType,
    this.symptoms,
    required this.createdAt,
    this.meetingLink,
    this.startTime,
    this.reason,
    this.prescriptionId,
    this.professionalType = 'doctor',
    this.duration = 30,
  });

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
      'appointmentType': appointmentType,
      'symptoms': symptoms,
      'createdAt': createdAt.toIso8601String(),
      'meetingLink': meetingLink,
      'startTime': startTime,
      'reason': reason,
      'prescriptionId': prescriptionId,
      'professionalType': professionalType,
      'duration': duration,
    };
  }
}