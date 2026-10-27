import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../models/appointment.dart';
import '../../models/chat_message.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../appointments/appointment_details_screen.dart';

/// A secure conversation with a care professional, tied to the booking it
/// came from.
class ChatScreen extends StatefulWidget {
  final Doctor doctor;
  final String? appointmentId;
  const ChatScreen({super.key, required this.doctor, this.appointmentId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final ChatProvider _chat = context.read<ChatProvider>();
  Appointment? _appointment;
  int _seen = 0;

  ModuleAccent get _accent => widget.doctor.professionalType == 'physio' ? ModuleAccent.physio : ModuleAccent.doctor;

  @override
  void initState() {
    super.initState();
    _chat.loadChatMessages(widget.doctor.id, professionalType: widget.doctor.professionalType, appointmentId: widget.appointmentId);
    _chat.addListener(_onMessages);
    if (widget.appointmentId != null) _loadAppointment();
  }

  void _onMessages() {
    if (_chat.messages.length != _seen) {
      _seen = _chat.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_scroll.position.maxScrollExtent, duration: AppMotion.medium, curve: AppMotion.enter);
  }

  Future<void> _loadAppointment() async {
    final provider = context.read<AppointmentProvider>();
    Appointment? find() {
      for (final a in provider.appointments) {
        if (a.id == widget.appointmentId) return a;
      }
      return null;
    }

    var a = find();
    if (a == null) {
      await provider.loadAppointments();
      a = find();
    }
    if (mounted) setState(() => _appointment = a);
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _chat.sendMessage(message: text, type: MessageType.text);
    _text.clear();
  }

  @override
  void dispose() {
    _chat.removeListener(_onMessages);
    _chat.disconnectSocket();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    final user = context.read<AuthProvider>().user;
    final me = user?.profileId ?? user?.id;
    final d = widget.doctor;
    return ModuleTheme(
      accent: _accent,
      child: Scaffold(
        backgroundColor: AppColors.bgSecondary,
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft, size: 22), onPressed: () => Navigator.of(context).maybePop()),
          title: Row(
            children: [
              AppAvatar(name: d.name, imageUrl: d.imageUrl, size: 38, color: _accent.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                    if (d.specialty.isNotEmpty)
                      Text(d.specialty, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_appointment != null)
              IconButton(
                tooltip: 'Appointment',
                icon: const Icon(LucideIcons.calendarDays, size: 21),
                onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => AppointmentDetailsScreen(appointment: _appointment!))),
              ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: p.isLoading
                  ? const AppLoading()
                  : p.error != null && p.messages.isEmpty
                  ? Center(
                      child: AppEmptyState(
                        illustration: Illustrations.offline,
                        title: 'Couldn’t open this chat',
                        message: p.error,
                        actionLabel: 'Try again',
                        onAction: () => _chat.loadChatMessages(d.id, professionalType: d.professionalType, appointmentId: widget.appointmentId),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: p.messages.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return _context();
                        final m = p.messages[i - 1];
                        final prev = i > 1 ? p.messages[i - 2] : null;
                        final newDay = prev == null || !_sameDay(prev.timestamp, m.timestamp);
                        return Column(
                          children: [
                            if (newDay) _DayChip(date: m.timestamp),
                            _Bubble(message: m, mine: m.senderId == me, accent: _accent),
                          ],
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        cursorColor: _accent.color,
                        style: AppType.sans(fontSize: AppType.body + 1, color: AppColors.textStrong),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          filled: true,
                          fillColor: AppColors.panel,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: _text,
                      builder: (_, _) => AppPressable(
                        onTap: _text.text.trim().isEmpty ? null : _send,
                        semanticLabel: 'Send',
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _text.text.trim().isEmpty ? AppColors.panel : _accent.color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.sendHorizontal, size: 19, color: _text.text.trim().isEmpty ? AppColors.textTertiary : Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Widget _context() {
    final a = _appointment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.lock, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    a == null
                        ? 'Messages are private to you and your care team'
                        : 'About your ${a.isVideo ? 'video call' : 'visit'} on ${DateFormat('d MMM, h:mm a').format(a.dateTime)}',
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  const _DayChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final d = date.toLocal();
    final now = DateTime.now();
    final label = d.year == now.year && d.month == now.month && d.day == now.day ? 'Today' : DateFormat('d MMMM').format(d);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label, style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final ModuleAccent accent;
  const _Bubble({required this.message, required this.mine, required this.accent});

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: mine ? accent.color : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.message,
              style: AppType.sans(fontSize: AppType.body + 1, height: 1.4, color: mine ? Colors.white : AppColors.textStrong),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat('h:mm a').format(message.timestamp.toLocal()),
              style: AppType.sans(fontSize: AppType.micro, color: mine ? Colors.white70 : AppColors.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );
}
