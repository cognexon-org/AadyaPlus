class PrescribedMedicine {
  final String medicineName;
  final String genericName;
  final String dosage;
  final String frequency;
  final String duration;
  final int prescribedQuantity;
  final int dispensedQuantity;
  final String instructions;
  final String unit;

  const PrescribedMedicine({
    required this.medicineName,
    this.genericName = '',
    required this.dosage,
    required this.frequency,
    this.duration = '',
    this.prescribedQuantity = 0,
    this.dispensedQuantity = 0,
    this.instructions = '',
    this.unit = '',
  });

  factory PrescribedMedicine.fromJson(
    Map<String, dynamic> json, {
    int dispensedQuantity = 0,
  }) {
    return PrescribedMedicine(
      medicineName: (json['medicineName'] ?? json['name'] ?? '').toString(),
      genericName: (json['genericName'] ?? '').toString(),
      dosage: (json['dosage'] ?? '').toString(),
      frequency: (json['frequency'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      prescribedQuantity: _toInt(json['prescribedQuantity'] ?? json['quantity']),
      dispensedQuantity: dispensedQuantity,
      instructions: (json['instructions'] ?? json['notes'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class Prescription {
  final String id;
  final String prescriptionNumber;
  final String doctorName;
  final String doctorSpecialization;
  final DateTime issuedAt;
  final DateTime validUntil;
  final String status;
  final String pharmacyStatus;
  final List<String> diagnosis;
  final List<String> symptoms;
  final List<PrescribedMedicine> medicines;
  final List<Map<String, dynamic>> labTests;
  final List<Map<String, dynamic>> exercises;
  final String advice;
  final String patientInstructions;
  final DateTime? followupDate;
  final String followupInstructions;

  const Prescription({
    required this.id,
    this.prescriptionNumber = '',
    required this.doctorName,
    this.doctorSpecialization = '',
    required this.issuedAt,
    required this.validUntil,
    this.status = 'issued',
    this.pharmacyStatus = 'not_dispensed',
    this.diagnosis = const [],
    this.symptoms = const [],
    this.medicines = const [],
    this.labTests = const [],
    this.exercises = const [],
    this.advice = '',
    this.patientInstructions = '',
    this.followupDate,
    this.followupInstructions = '',
  });

  bool get isExpired => validUntil.isBefore(DateTime.now());
  bool get isActive => status == 'issued' && !isExpired;

  int get remainingDays {
    final diff = validUntil.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get statusText {
    if (status == 'cancelled') return 'Cancelled';
    if (status == 'superseded') return 'Superseded';
    if (isExpired) return 'Expired';
    switch (pharmacyStatus) {
      case 'fully_dispensed':
        return 'Dispensed';
      case 'partially_dispensed':
        return 'Partially Dispensed';
      case 'not_dispensed':
        return 'Issued';
      default:
        return status == 'issued' ? 'Issued' : status;
    }
  }

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final professional = json['doctorId'] is Map
        ? Map<String, dynamic>.from(json['doctorId'])
        : json['physioId'] is Map
            ? Map<String, dynamic>.from(json['physioId'])
            : <String, dynamic>{};

    final specializationRaw = professional['specialization'];
    final specialization = specializationRaw is List
        ? specializationRaw.map((e) => e.toString()).join(', ')
        : (specializationRaw ?? professional['services'] ?? '').toString();

    final dispensedItems = _mapList(json['dispensedItems']);
    final medicines = _mapList(json['medicines']).map((med) {
      final name = (med['medicineName'] ?? med['name'] ?? '').toString().toLowerCase();
      final dispensed = dispensedItems
          .where((item) => (item['medicineName'] ?? '').toString().toLowerCase() == name)
          .fold<int>(0, (sum, item) => sum + _toInt(item['quantity']));
      return PrescribedMedicine.fromJson(med, dispensedQuantity: dispensed);
    }).toList();

    final adviceEntries = _mapList(json['advice']);
    final adviceText = adviceEntries
        .map((item) => (item['advice'] ?? '').toString().trim())
        .where((text) => text.isNotEmpty)
        .join('\n');

    final issuedAt = _parseDate(json['issuedAt']) ?? _parseDate(json['createdAt']) ?? DateTime.now();
    final expiresAt = _parseDate(json['expiresAt']) ?? issuedAt.add(const Duration(days: 30));

    return Prescription(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      prescriptionNumber: (json['prescriptionNumber'] ?? '').toString(),
      doctorName: (professional['name'] ?? json['doctorName'] ?? 'Professional').toString(),
      doctorSpecialization: specialization,
      issuedAt: issuedAt,
      validUntil: expiresAt,
      status: (json['status'] ?? 'issued').toString(),
      pharmacyStatus: (json['pharmacyStatus'] ?? 'not_dispensed').toString(),
      diagnosis: _stringList(json['diagnosis']),
      symptoms: _stringList(json['symptoms']),
      medicines: medicines,
      labTests: _mapList(json['labTests']),
      exercises: _mapList(json['exercises']),
      advice: adviceText.isNotEmpty ? adviceText : (json['notes'] ?? '').toString(),
      patientInstructions: (json['patientInstructions'] ?? '').toString(),
      followupDate: _parseDate(json['followUpDate']),
      followupInstructions: (json['followUpInstructions'] ?? '').toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
