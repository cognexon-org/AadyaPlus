import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/notification_provider.dart';
import 'package:aadya_plus/models/notification_item.dart';
import 'package:aadya_plus/utils/constants.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox();
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                child: Text(
                  'Mark all read',
                  style: TextStyle(color: AppConstants.primaryColor),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    Text(
                      'No notifications yet',
                      style:
                          TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We'll notify you when something arrives",
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.todayNotifications.isNotEmpty) ...[
                  _buildDateHeader('Today'),
                  ...provider.todayNotifications
                      .map((n) => _buildNotificationTile(context, n, provider)),
                ],
                if (provider.yesterdayNotifications.isNotEmpty) ...[
                  _buildDateHeader('Yesterday'),
                  ...provider.yesterdayNotifications
                      .map((n) => _buildNotificationTile(context, n, provider)),
                ],
                if (provider.earlierNotifications.isNotEmpty) ...[
                  _buildDateHeader('Earlier'),
                  ...provider.earlierNotifications
                      .map((n) => _buildNotificationTile(context, n, provider)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, NotificationItem item,
      NotificationProvider provider) {
    IconData icon;
    Color color;
    switch (item.type) {
      case 'appointment':
        icon = Icons.calendar_today;
        color = Colors.blue;
        break;
      case 'prescription':
        icon = Icons.description;
        color = Colors.purple;
        break;
      case 'lab':
        icon = Icons.science;
        color = Colors.teal;
        break;
      case 'payment':
        icon = Icons.payment;
        color = Colors.green;
        break;
      case 'pharmacy':
        icon = Icons.local_pharmacy;
        color = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    final timeAgo = _timeAgo(item.date);

    return GestureDetector(
      onTap: () {
        if (!item.isRead) {
          provider.markAsRead(item.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : AppConstants.primaryColor.withOpacity(0.04),
          border: Border.all(
            color: item.isRead ? Colors.grey[200]! : AppConstants.primaryColor.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight:
                                item.isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
