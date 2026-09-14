import 'package:aadya_plus/models/notification_item.dart';
import 'package:aadya_plus/providers/notification_provider.dart';
import 'package:aadya_plus/services/push_notification_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().loadNotifications(silent: true);
    });
  }

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
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  try {
                    await provider.markAllAsRead();
                  } catch (error) {
                    if (!context.mounted) return;
                    _showError(context, error);
                  }
                },
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
            if (provider.isLoading && provider.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.notifications.isEmpty) {
              return RefreshIndicator(
                onRefresh: provider.loadNotifications,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 150),
                    Icon(Icons.notifications_none,
                        size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        provider.error ?? 'No notifications yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Pull down to refresh',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: provider.loadNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (provider.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Last refresh failed: ${provider.error}',
                        style: TextStyle(color: Colors.amber.shade900),
                      ),
                    ),
                  if (provider.todayNotifications.isNotEmpty) ...[
                    _buildDateHeader('Today'),
                    ...provider.todayNotifications.map(
                      (item) => _buildNotificationTile(context, item, provider),
                    ),
                  ],
                  if (provider.yesterdayNotifications.isNotEmpty) ...[
                    _buildDateHeader('Yesterday'),
                    ...provider.yesterdayNotifications.map(
                      (item) => _buildNotificationTile(context, item, provider),
                    ),
                  ],
                  if (provider.earlierNotifications.isNotEmpty) ...[
                    _buildDateHeader('Earlier'),
                    ...provider.earlierNotifications.map(
                      (item) => _buildNotificationTile(context, item, provider),
                    ),
                  ],
                ],
              ),
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

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationItem item,
    NotificationProvider provider,
  ) {
    final style = _styleForType(item.type);
    final timeAgo = _timeAgo(item.date);

    return GestureDetector(
      onTap: () async {
        if (!item.isRead) {
          try {
            await provider.markAsRead(item.id);
          } catch (error) {
            if (context.mounted) _showError(context, error);
          }
        }
        await PushNotificationService.instance
            .openNotificationData(item.navigationData);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead
              ? Colors.white
              : AppConstants.primaryColor.withOpacity(0.04),
          border: Border.all(
            color: item.isRead
                ? Colors.grey[200]!
                : AppConstants.primaryColor.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: style.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.color, size: 22),
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
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppConstants.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeAgo,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color}) _styleForType(String type) {
    switch (type) {
      case 'appointment':
        return (icon: Icons.calendar_today, color: Colors.blue);
      case 'prescription':
        return (icon: Icons.description, color: Colors.purple);
      case 'lab_report':
      case 'diagnostic':
        return (icon: Icons.science, color: Colors.teal);
      case 'payment':
        return (icon: Icons.payment, color: Colors.green);
      case 'order':
        return (icon: Icons.local_pharmacy, color: Colors.orange);
      case 'chat':
        return (icon: Icons.chat_bubble_outline, color: Colors.indigo);
      default:
        return (icon: Icons.notifications, color: Colors.grey);
    }
  }

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }
}
