import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../models/doctor.dart';
import '../../providers/chat_provider.dart';
import 'chat_screen.dart';

/// Conversations with the doctors, physios, labs and pharmacies the
/// patient has a booking or order with.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ChatProvider>().loadSessions());
  }

  String _time(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return DateFormat('h:mm a').format(d);
    return DateFormat('d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    final sessions = p.sessions.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((s) => s['professional'] is Map).toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Messages'),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: p.loadSessions,
        child: p.isLoadingSessions && sessions.isEmpty
            ? const AppListSkeleton(count: 5)
            : sessions.isEmpty
            ? ListView(
                children: [
                  AppEmptyState(
                    illustration: p.error != null ? Illustrations.offline : Illustrations.emptyData,
                    title: p.error != null ? 'Couldn’t load messages' : 'No conversations yet',
                    message: p.error ?? 'After you book, you can message your doctor or physio from the appointment.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final prof = mapOf(s['professional']);
                  final type = (s['professionalType'] ?? 'doctor').toString();
                  final spec = prof['specialization'] is List ? (prof['specialization'] as List).join(', ') : (prof['specialization'] ?? '').toString();
                  final last = mapOf(s['lastMessage']);
                  final unread = last.isNotEmpty && last['isRead'] == false && last['senderType'] != 'patient';
                  final accent = type == 'physio' ? ModuleAccent.physio : type == 'pathology' ? ModuleAccent.lab : type == 'pharmacy' ? ModuleAccent.pharmacy : ModuleAccent.doctor;
                  final name = (prof['name'] ?? prof['labName'] ?? 'Care team').toString();
                  return AppEntrance(
                    index: i.clamp(0, 6),
                    child: AppPressable(
                      scale: 0.99,
                      onTap: () => Navigator.of(context).push(AppPageRoute(
                        builder: (_) => ChatScreen(
                          doctor: Doctor(
                            id: (prof['_id'] ?? s['professionalId'] ?? '').toString(),
                            name: name,
                            specialty: spec,
                            hospital: '',
                            rating: 0,
                            reviews: 0,
                            consultationFee: 0,
                            experience: 0,
                            imageUrl: (prof['profileImage'] ?? '').toString(),
                            description: '',
                            languages: const [],
                            availability: const {},
                            professionalType: type,
                          ),
                          appointmentId: s['appointmentId']?.toString(),
                        ),
                      )),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: unread ? AppColors.brandVeryLight : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: unread ? AppColors.brandLight : AppColors.borderStrong),
                        ),
                        child: Row(
                          children: [
                            AppAvatar(name: name, imageUrl: prof['profileImage']?.toString(), size: 48, radius: 15, color: accent.color),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                                      ),
                                      Text(_time(last['createdAt']), style: AppType.sans(fontSize: AppType.caption, color: unread ? AppColors.brand : AppColors.textTertiary)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    last.isEmpty ? (spec.isNotEmpty ? spec : 'Start the conversation') : (last['content'] ?? 'Attachment').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.sans(fontSize: AppType.small, fontWeight: unread ? FontWeight.w700 : FontWeight.w400, color: unread ? AppColors.textStrong : AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: 8),
                              Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
