class PrescribedMedicine {
  final String medicineName;
  final String genericName;
  final String dosage;
  final String frequency;
  final String duration;
  final int prescribedQuantity;
  final int dispensedQuantity;
  final String instructions;

  PrescribedMedicine({
    required this.medicineName,
    this.genericName = '',
    required this.dosage,
    required this.frequency,
    this.duration = '',
    this.prescribedQuantity = 0,
    this.dispensedQuantity = 0,
    this.instructions = '',
  });

  factory PrescribedMedicine.fromJson(Map<String, dynamic> json) {
    return PrescribedMedicine(
      medicineName: json['medicineName'] ?? '',
      genericName: json['genericName'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
      prescribedQuantity: json['prescribedQuantity'] ?? 0,
      dispensedQuantity: json['dispensedQuantity'] ?? 0,
      instructions: json['instructions'] ?? '',
    );
  }
}

class Prescription {
  final String id;
  final String doctorName;
  final String doctorSpecialization;
  final DateTime issuedAt;
  final DateTime validUntil;
  final String status;
  final String pharmacyStatus;
  final List<String> diagnosis;
  final List<PrescribedMedicine> medicines;
  final List<Map<String, dynamic>> labTests;
  final List<Map<String, dynamic>> exercises;
  final String advice;
  final DateTime? followupDate;

  Prescription({
    required this.id,
    required this.doctorName,
    this.doctorSpecialization = '',
    required this.issuedAt,
    required this.validUntil,
    this.status = 'active',
    this.pharmacyStatus = 'not_dispensed',
    this.diagnosis = const [],
    this.medicines = const [],
    this.labTests = const [],
    this.exercises = const [],
    this.advice = '',
    this.followupDate,
  });

  bool get isExpired => validUntil.isBefore(DateTime.now());
  bool get isActive => status == 'active' && !isExpired;

  int get remainingDays {
    final diff = validUntil.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get statusText {
    if (isExpired) return 'Expired';
    switch (pharmacyStatus) {
      case 'fully_dispensed':
        return 'Completed';
      case 'partially_dispensed':
        return 'Partially Filled';
      case 'not_dispensed':
        return 'Not Dispensed';
      default:
        return 'Active';
    }
  }

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['_id'] ?? json['id'] ?? '',
      doctorName: json['doctorId']?['name'] ?? json['doctorName'] ?? 'Doctor',
      doctorSpecialization:
          (json['doctorId']?['specialization'] is List
              ? (json['doctorId']['specialization'] as List).firstOrNull
              : json['doctorId']?['specialization']) ??
          json['doctorSpecialization'] ??
          '',
      issuedAt: DateTime.tryParse(json['issuedAt'] ?? '') ?? DateTime.now(),
      validUntil: DateTime.tryParse(
              json['validUntil'] ?? json['expiresAt'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      status: json['status'] ?? 'active',
      pharmacyStatus: json['pharmacyStatus'] ?? 'not_dispensed',
      diagnosis: List<String>.from(json['diagnosis'] ?? []),
      medicines: (json['medicines'] as List?)
              ?.map((m) => PrescribedMedicine.fromJson(m))
              .toList() ??
          [],
      labTests:
          List<Map<String, dynamic>>.from(json['labTests'] ?? []),
      exercises:
          List<Map<String, dynamic>>.from(json['exercises'] ?? []),
      advice: json['advice'] ?? '',
      followupDate: json['followupDate'] != null
          ? DateTime.tryParse(json['followupDate'])
          : null,
    );
  }
}
