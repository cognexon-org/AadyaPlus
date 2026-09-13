import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aadya_plus/models/notification_item.dart';
import 'package:aadya_plus/utils/constants.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  List<NotificationItem> get todayNotifications {
    final today = DateTime.now();
    return _notifications.where((n) =>
        n.date.year == today.year &&
        n.date.month == today.month &&
        n.date.day == today.day).toList();
  }

  List<NotificationItem> get yesterdayNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications.where((n) =>
        n.date.year == yesterday.year &&
        n.date.month == yesterday.month &&
        n.date.day == yesterday.day).toList();
  }

  List<NotificationItem> get earlierNotifications {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    return _notifications.where((n) => n.date.isBefore(twoDaysAgo)).toList();
  }

  NotificationProvider() {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return; // Non-auth users have no notifications
      }

      final response = await http.get(
        Uri.parse(AppConstants.notificationsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> notifDocs = responseData['notifications'] ?? [];

        _notifications = notifDocs.map((doc) {
          return NotificationItem(
            id: doc['_id'] ?? '',
            type: doc['type'] ?? 'system',
            title: doc['title'] ?? 'Notification',
            message: doc['message'] ?? '',
            date: doc['createdAt'] != null ? DateTime.parse(doc['createdAt']) : DateTime.now(),
            isRead: doc['isRead'] ?? false,
          );
        }).toList();

      } else {
        print('Backend error: ${responseData['message']}');
      }

    } catch (e) {
      print('HTTP error fetching notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    notifyListeners();
  }
}
