import 'dart:async';

import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/models/consultation_session.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/screens/appointments/prescription_details_screen.dart';
import 'package:aadya_plus/screens/appointments/video_call_screen.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/services/consultation_service.dart';
import 'package:aadya_plus/core/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ConsultationScreen extends StatefulWidget {
  final Appointment appointment;

  const ConsultationScreen({super.key, required this.appointment});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  ConsultationSnapshot? _snapshot;
  bool _loading = true;
  bool _actionBusy = false;
  bool _consentChecked = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
    // The countdown ticks every second; the server is asked every 15.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final state = _snapshot?.session;
      if (mounted && state != null && !state.isEnded) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await ConsultationService.instance.getByAppointment(widget.appointment.id);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _consentChecked = snapshot.session.consentAccepted || _consentChecked;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _checkIn() async {
    if (widget.appointment.isVideo && !_consentChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tick the consent box to check in')),
      );
      return;
    }

    setState(() => _actionBusy = true);
    try {
      await ConsultationService.instance.checkIn(
        widget.appointment.id,
        teleconsultationAccepted: widget.appointment.isVideo ? _consentChecked : false,
      );
      await _load(silent: true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  /// Camera and microphone, asked for before the call opens. Without the
  /// runtime grant Android gives the call page no camera or mic at all.
  Future<bool> _ensureCallPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses.values.every((s) => s.isGranted)) return true;
    if (!mounted) return false;
    final blocked = statuses.values.any((s) => s.isPermanentlyDenied);
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera and microphone needed'),
        content: Text(
          blocked
              ? 'Allow camera and microphone for Aadya Plus in Settings to join the video consultation.'
              : 'The doctor needs to see and hear you. Allow camera and microphone to join.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(blocked ? 'Open settings' : 'Try again'),
          ),
        ],
      ),
    );
    if (open != true) return false;
    if (blocked) {
      await openAppSettings();
      return false;
    }
    return _ensureCallPermissions();
  }

  Future<void> _join() async {
    if (!await _ensureCallPermissions()) return;
    if (!mounted) return;
    setState(() => _actionBusy = true);
    try {
      final result = await ConsultationService.instance.join(widget.appointment.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            appointmentId: widget.appointment.id,
            joinUrl: result.joinUrl,
            doctorName: widget.appointment.doctorName,
          ),
        ),
      );
      await _load(silent: true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _pay() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          entityType: 'appointment',
          entityId: widget.appointment.id,
          title: 'Video consultation with ${widget.appointment.doctorName}',
          expectedAmount: widget.appointment.totalAmount,
        ),
      ),
    );
    if (paid == true && mounted) {
      await context.read<AppointmentProvider>().loadAppointments();
      await _load();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst(RegExp(r'^\w*Exception:\s*'), '')), backgroundColor: AppColors.error),
    );
  }

  ModuleAccent get _accent => widget.appointment.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;

  /// 0 pay, 1 check in, 2 waiting, 3 join, 4 done.
  int _stage(ConsultationSessionState s) {
    if (s.isEnded) return 4;
    if (s.paymentRequired) return 0;
    if (s.canJoin) return 3;
    if (s.isCheckedIn) return 2;
    return 1;
  }

  String _countdown(DateTime at) {
    final d = at.difference(DateTime.now());
    if (d.isNegative) return 'now';
    if (d.inDays >= 1) return 'in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    final h = d.inHours, m = d.inMinutes % 60, sec = d.inSeconds % 60;
    if (h > 0) return 'in ${h}h ${m}m';
    return 'in ${m}m ${sec.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return ModuleTheme(
      accent: _accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppTopBar(title: 'Video consultation'),
        body: _loading
            ? const AppDetailSkeleton()
            : _error != null
            ? Center(
                child: AppEmptyState(
                  illustration: Illustrations.offline,
                  title: 'Couldn’t open the consultation',
                  message: _error!.replaceFirst(RegExp(r'^\w*Exception:\s*'), ''),
                  actionLabel: 'Try again',
                  onAction: _load,
                ),
              )
            : RefreshIndicator(color: _accent.color, onRefresh: _load, child: _content()),
      ),
    );
  }

  Widget _content() {
    final s = _snapshot!.session;
    final a = widget.appointment;
    final stage = _stage(s);
    final scheduled = s.scheduledAt ?? a.dateTime;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        AppEntrance(
          child: Column(
            children: [
              _Presence(name: a.doctorName, live: stage == 3 || s.isInProgress, waiting: stage == 2, accent: _accent),
              const SizedBox(height: 14),
              Text(a.doctorName, style: AppType.sans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              Text(a.specialty, style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, d MMM · h:mm a').format(scheduled),
                style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w600, color: _accent.color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (stage < 4) AppEntrance(index: 1, child: _Steps(stage: stage, accent: _accent)),
        const SizedBox(height: 18),
        AppEntrance(index: 2, child: _stageCard(s, stage)),
        if (stage == 4) ..._summary(s),
      ],
    );
  }

  Widget _stageCard(ConsultationSessionState s, int stage) {
    final a = widget.appointment;
    switch (stage) {
      case 0:
        return _Panel(
          icon: LucideIcons.creditCard,
          title: 'Pay to confirm your call',
          body: '${appRupees(a.totalAmount)} is due before you can check in.',
          action: AppButton(label: 'Pay ${appRupees(a.totalAmount)}', icon: LucideIcons.lock, loading: _actionBusy, onPressed: _pay),
        );
      case 1:
        final opens = s.joinOpensAt;
        return _Panel(
          icon: LucideIcons.clipboardCheck,
          title: s.canCheckIn ? 'Check in when you’re ready' : 'Check-in opens ${opens == null ? 'soon' : _countdown(opens)}',
          body: s.canCheckIn
              ? 'Find a quiet, well-lit place. Your ${a.isPhysio ? 'physio' : 'doctor'} is told you’re waiting.'
              : 'You can check in from 15 minutes before the start. This page updates by itself.',
          child: a.isVideo
              ? InkWell(
                  onTap: _actionBusy ? null : () => setState(() => _consentChecked = !_consentChecked),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _consentChecked,
                        activeColor: _accent.color,
                        onChanged: _actionBusy ? null : (v) => setState(() => _consentChecked = v == true),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'I agree to consult by video. What’s discussed is kept in my Aadya Plus health record.',
                            style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          action: AppButton(
            label: 'Check in',
            icon: LucideIcons.logIn,
            loading: _actionBusy,
            onPressed: s.canCheckIn && (!a.isVideo || _consentChecked) ? _checkIn : null,
          ),
        );
      case 2:
        return const _Panel(
          icon: LucideIcons.armchair,
          title: 'You’re in the waiting room',
          body: 'We’ll open the call as soon as they’re ready. Keep this screen open.',
        );
      case 3:
        return _Panel(
          icon: LucideIcons.video,
          title: s.isInProgress ? 'Your call is live' : 'They’re ready for you',
          body: 'You’ll be asked for camera and microphone access.',
          action: AppButton(label: s.isInProgress ? 'Rejoin call' : 'Join video call', icon: LucideIcons.video, loading: _actionBusy, onPressed: _join),
        );
      default:
        return _Panel(
          icon: s.status == 'ended' ? LucideIcons.circleCheckBig : LucideIcons.circleX,
          title: s.status == 'ended' ? 'Consultation finished' : PatientStatus.of(s.status).label,
          body: s.status == 'ended' ? 'Here’s what was noted.' : '',
        );
    }
  }

  List<Widget> _summary(ConsultationSessionState s) {
    final c = s.clinicalSummary;
    String text(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join(', ') : (v?.toString() ?? '');
    final rows = [
      ('Diagnosis', text(c?['diagnosis'])),
      ('Advice', text(c?['advice'])),
      ('Follow-up', text(c?['followUpNotes'])),
    ].where((r) => r.$2.isNotEmpty).toList();
    return [
      if (rows.isNotEmpty) ...[
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                      Text(value, style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w600, color: AppColors.textStrong)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (widget.appointment.prescriptionId != null && widget.appointment.prescriptionId!.isNotEmpty) ...[
        const SizedBox(height: 14),
        AppButton(
          label: 'View prescription',
          icon: LucideIcons.fileText,
          onPressed: () => Navigator.of(context).push(
            AppPageRoute(builder: (_) => PrescriptionDetailsScreen(prescriptionId: widget.appointment.prescriptionId!)),
          ),
        ),
      ],
    ];
  }
}

/// The professional's avatar: a slow ripple while you wait, a green ring
/// once the call is open.
class _Presence extends StatefulWidget {
  final String name;
  final bool live;
  final bool waiting;
  final ModuleAccent accent;
  const _Presence({required this.name, required this.live, required this.waiting, required this.accent});

  @override
  State<_Presence> createState() => _PresenceState();
}

class _PresenceState extends State<_Presence> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.live ? AppColors.health : widget.accent.color;
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.waiting || widget.live)
              for (final lag in const [0.0, 0.5])
                Builder(
                  builder: (_) {
                    final v = (_c.value + lag) % 1;
                    return Container(
                      width: 92 + 48 * v,
                      height: 92 + 48 * v,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.35 * (1 - v)), width: 2),
                      ),
                    );
                  },
                ),
            child!,
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
          child: AppAvatar(name: widget.name, size: 84, color: widget.accent.color),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  final int stage;
  final ModuleAccent accent;
  const _Steps({required this.stage, required this.accent});

  static const _labels = ['Pay', 'Check in', 'Wait', 'Join'];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < _labels.length; i++) ...[
        Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: AppMotion.medium,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= stage ? accent.color : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _labels[i],
                style: AppType.sans(
                  fontSize: AppType.caption,
                  fontWeight: i == stage ? FontWeight.w800 : FontWeight.w500,
                  color: i <= stage ? AppColors.textStrong : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (i < _labels.length - 1) const SizedBox(width: 6),
      ],
    ],
  );
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? child;
  final Widget? action;
  const _Panel({required this.icon, required this.title, required this.body, this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: accent.veryLight, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: accent.color),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong))),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: AppType.sans(fontSize: AppType.small, height: 1.45, color: AppColors.textSecondary)),
          ],
          if (child != null) ...[const SizedBox(height: 6), child!],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
