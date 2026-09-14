class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime date;
  final Map<String, dynamic> data;
  final String actionUrl;
  final String relatedEntity;
  final String relatedEntityId;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.date,
    this.data = const {},
    this.actionUrl = '',
    this.relatedEntity = '',
    this.relatedEntityId = '',
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return NotificationItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? 'system').toString(),
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? '').toString(),
      date: DateTime.tryParse(
            (json['createdAt'] ?? json['date'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
      // Backend B1 uses `read`; `isRead` is retained for older servers.
      isRead: json['read'] == true || json['isRead'] == true,
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      actionUrl: (json['actionUrl'] ?? '').toString(),
      relatedEntity: (json['relatedEntity'] ?? '').toString(),
      relatedEntityId: (json['relatedEntityId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> get navigationData => <String, dynamic>{
        ...data,
        'notificationId': id,
        'type': type,
        if (actionUrl.isNotEmpty) 'actionUrl': actionUrl,
        if (relatedEntity.isNotEmpty) 'relatedEntity': relatedEntity,
        if (relatedEntityId.isNotEmpty) 'relatedEntityId': relatedEntityId,
      };
}
