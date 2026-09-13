class NotificationItem {
  final String id;
  final String type; // appointment, prescription, lab, payment, pharmacy
  final String title;
  final String message;
  final DateTime date;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.date,
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }
}
