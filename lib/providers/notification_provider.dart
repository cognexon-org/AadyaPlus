import 'dart:async';
import 'dart:convert';

import 'package:aadya_plus/models/notification_item.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';

class NotificationProvider with ChangeNotifier {
  final List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  bool _authenticated = false;
  int _unreadCount = 0;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<int>? _pushSubscription;

  NotificationProvider() {
    _pushSubscription =
        PushNotificationService.instance.notificationEvents.listen((_) {
      if (_authenticated) loadNotifications(silent: true);
    });
  }

  List<NotificationItem> get notifications =>
      List<NotificationItem>.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get error => _error;

  List<NotificationItem> get todayNotifications {
    final today = DateTime.now();
    return _notifications
        .where((n) =>
            n.date.year == today.year &&
            n.date.month == today.month &&
            n.date.day == today.day)
        .toList();
  }

  List<NotificationItem> get yesterdayNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications
        .where((n) =>
            n.date.year == yesterday.year &&
            n.date.month == yesterday.month &&
            n.date.day == yesterday.day)
        .toList();
  }

  List<NotificationItem> get earlierNotifications {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    return _notifications.where((n) => n.date.isBefore(yesterdayStart)).toList();
  }

  /// Called by ChangeNotifierProxyProvider whenever authentication changes.
  void setAuthenticated(bool value) {
    if (_authenticated == value) return;
    _authenticated = value;
    _pollTimer?.cancel();

    if (!value) {
      _notifications.clear();
      _unreadCount = 0;
      _error = null;
      Future.microtask(notifyListeners);
      return;
    }

    Future.microtask(() => loadNotifications());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => loadNotifications(silent: true),
    );
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!_authenticated) return;

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await http.get(
        http.apiUri('/notifications', queryParameters: {'limit': 100}),
      );
      final data = _decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(
          (data['message'] ?? data['error'] ?? 'Unable to load notifications')
              .toString(),
        );
      }

      final rows = data['notifications'] is List
          ? data['notifications'] as List
          : const [];
      _notifications
        ..clear()
        ..addAll(rows.whereType<Map>().map(
              (item) => NotificationItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ));
      _unreadCount = _asInt(data['unreadCount']);
      _error = null;
    } catch (error) {
      _error = _cleanError(error);
      debugPrint('Notification refresh failed: $error');
    } finally {
      if (!silent) _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;

    _notifications[index].isRead = true;
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      final response = await http.put(http.apiUri('/notifications/$id/read'));
      final data = _decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(
          (data['message'] ?? data['error'] ?? 'Unable to mark notification read')
              .toString(),
        );
      }
    } catch (error) {
      if (index < _notifications.length && _notifications[index].id == id) {
        _notifications[index].isRead = false;
        _unreadCount++;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = _notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toSet();
    if (unreadIds.isEmpty && _unreadCount == 0) return;

    for (final item in _notifications) {
      item.isRead = true;
    }
    final previousUnread = _unreadCount;
    _unreadCount = 0;
    notifyListeners();

    try {
      final response = await http.put(http.apiUri('/notifications/read-all'));
      final data = _decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(
          (data['message'] ?? data['error'] ?? 'Unable to mark notifications read')
              .toString(),
        );
      }
    } catch (error) {
      for (final item in _notifications) {
        if (unreadIds.contains(item.id)) item.isRead = false;
      }
      _unreadCount = previousUnread;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteNotification(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final removed = _notifications.removeAt(index);
    if (!removed.isRead && _unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      final response = await http.delete(http.apiUri('/notifications/$id'));
      final data = _decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw Exception(
          (data['message'] ?? data['error'] ?? 'Unable to delete notification')
              .toString(),
        );
      }
    } catch (error) {
      final restoreIndex = index > _notifications.length ? _notifications.length : index;
      _notifications.insert(restoreIndex, removed);
      if (!removed.isRead) _unreadCount++;
      notifyListeners();
      rethrow;
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ??
        _notifications.where((item) => !item.isRead).length;
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }
}
