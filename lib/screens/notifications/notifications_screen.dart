import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../models/notification_item.dart';
import '../../providers/notification_provider.dart';
import '../../services/push_notification_service.dart';

/// Everything Aadya Plus told you, newest first: today, yesterday, earlier.
/// Tap to open what it's about; swipe away to delete.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationProvider>().loadNotifications());
  }

  static (IconData, Color) style(String type) => switch (type) {
    'appointment' || 'reminder' => (LucideIcons.calendarDays, ModuleAccent.doctor.color),
    'payment' => (LucideIcons.creditCard, AppColors.health),
    'prescription' => (LucideIcons.fileText, AppColors.brand),
    'lab_report' || 'diagnostic' => (LucideIcons.flaskConical, ModuleAccent.lab.color),
    'order' => (LucideIcons.pill, ModuleAccent.pharmacy.color),
    'chat' => (LucideIcons.messageCircle, AppColors.brand),
    _ => (LucideIcons.bell, AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationProvider>();
    final groups = [
      ('Today', p.todayNotifications),
      ('Yesterday', p.yesterdayNotifications),
      ('Earlier', p.earlierNotifications),
    ].where((g) => g.$2.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppTopBar(
        title: 'Notifications',
        subtitle: p.unreadCount > 0 ? '${p.unreadCount} unread' : null,
        actions: [
          if (p.unreadCount > 0)
            TextButton(onPressed: p.markAllAsRead, child: const Text('Mark all read')),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: p.loadNotifications,
        child: p.isLoading && p.notifications.isEmpty
            ? const AppListSkeleton(count: 6)
            : p.notifications.isEmpty
            ? ListView(
                children: [
                  AppEmptyState(
                    illustration: p.error != null ? Illustrations.offline : Illustrations.emptyNotifications,
                    title: p.error != null ? 'Couldn’t load notifications' : 'You’re all caught up',
                    message: p.error ?? 'Booking updates, reports and order tracking will show up here.',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final (label, items) in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                      child: Text(label, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ),
                    for (final (i, n) in items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppEntrance(index: i.clamp(0, 6), child: _Tile(item: n, provider: p)),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final NotificationItem item;
  final NotificationProvider provider;
  const _Tile({required this.item, required this.provider});

  String get _when {
    final d = item.date.toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _NotificationsScreenState.style(item.type);
    final messenger = ScaffoldMessenger.of(context);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(16)),
        child: const Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
      ),
      onDismissed: (_) async {
        try {
          await provider.deleteNotification(item.id);
        } catch (_) {
          messenger.showSnackBar(const SnackBar(content: Text('Couldn’t delete that notification')));
        }
      },
      child: AppPressable(
        onTap: () async {
          if (!item.isRead) provider.markAsRead(item.id).catchError((_) {});
          await PushNotificationService.instance.openNotificationData(item.navigationData);
        },
        scale: 0.99,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : AppColors.brandVeryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.isRead ? AppColors.borderStrong : AppColors.brandLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: color),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800, color: AppColors.textStrong),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_when, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(item.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
