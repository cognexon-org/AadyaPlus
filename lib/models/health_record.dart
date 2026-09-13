class HealthRecord {
  final String id;
  final String title;
  final String type;
  final DateTime date;
  final String? fileUrl;
  final String? doctorName;
  final String? hospitalName;
  final String? description;

  HealthRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.fileUrl,
    this.doctorName,
    this.hospitalName,
    this.description,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      date: DateTime.parse(json['date']),
      fileUrl: json['fileUrl'],
      doctorName: json['doctorName'],
      hospitalName: json['hospitalName'],
      description: json['description'],
    );
  }
}