import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_ui.dart';
import '../../models/appointment.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../services/feedback_service.dart';
import '../../widgets/appointment_sheets.dart';
import '../chat/chat_screen.dart';
import '../doctors/doctor_detail_screen.dart';
import '../payments/payment_checkout_screen.dart';
import 'consultation_screen.dart';
import 'prescription_details_screen.dart';
import 'reschedule_appointment_screen.dart';

/// One appointment in full: where it stands, when and where it happens,
/// what was paid, and what can be done with it now.
class AppointmentDetailsScreen extends StatefulWidget {
  final Appointment appointment;
  const AppointmentDetailsScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  bool? _reviewed;

  @override
  void initState() {
    super.initState();
    if (widget.appointment.status == 'completed') {
      FeedbackService.instance.reviewedAppointmentIds().then((ids) {
        if (mounted) setState(() => _reviewed = ids.contains(widget.appointment.id));
      }).catchError((_) {});
    }
  }

  /// The freshest copy of this appointment the app has.
  Appointment get _a {
    for (final a in context.watch<AppointmentProvider>().appointments) {
      if (a.id == widget.appointment.id) return a;
    }
    return widget.appointment;
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(AppPageRoute(builder: (_) => screen));
    if (mounted) context.read<AppointmentProvider>().loadAppointments();
  }

  void _chat(Appointment a) {
    final known = context.read<DoctorProvider>().findById(a.doctorId);
    final doctor = known ??
        Doctor(
          id: a.doctorId,
          name: a.doctorName,
          specialty: a.specialty,
          hospital: a.hospital,
          rating: 0,
          reviews: 0,
          consultationFee: a.consultationFee,
          experience: 0,
          imageUrl: a.imageUrl,
          description: '',
          languages: const [],
          availability: const {},
          professionalType: a.professionalType,
        );
    _push(ChatScreen(doctor: doctor, appointmentId: a.id));
  }

  Future<void> _directions(Appointment a) async {
    final q = Uri.encodeComponent([a.clinicName, a.clinicAddress].where((e) => e.isNotEmpty).join(', '));
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
      mode: LaunchMode.externalApplication,
    );
  }

  (String, String) _banner(Appointment a) {
    final who = a.isPhysio ? 'your physio' : a.doctorName;
    return switch (a.status.toLowerCase()) {
      'pending' => ('Waiting for confirmation', '$who will confirm this booking soon.'),
      'confirmed' || 'accepted' || 'rescheduled' => (
        'You’re all set',
        a.isVideo ? 'Join from here up to 15 minutes before the start.' : 'Please arrive 10 minutes early.',
      ),
      'in_progress' => ('Happening now', a.isVideo ? 'Your call is open — join now.' : 'Your visit is in progress.'),
      'completed' => ('Visit completed', a.prescriptionId != null ? 'Your prescription is ready below.' : 'Hope you’re feeling better.'),
      'cancelled' => ('Cancelled', a.cancellationReason?.isNotEmpty == true ? a.cancellationReason! : 'This booking was cancelled.'),
      'rejected' => ('Declined', '$who couldn’t take this booking. Try another time or doctor.'),
      'no_show' => ('Marked as missed', 'Book again whenever you’re ready.'),
      _ => (PatientStatus.of(a.status).label, ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final accent = a.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;
    final status = PatientStatus.of(a.status);
    final (title, line) = _banner(a);
    final (visitIcon, visitLabel) = switch (a.appointmentType.toLowerCase()) {
      'video' => (LucideIcons.video, 'Video call'),
      'home' => (LucideIcons.house, 'Home visit'),
      _ => (LucideIcons.building2, 'Clinic visit'),
    };
    final active = !a.isTerminal;
    return ModuleTheme(
      accent: accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppTopBar(title: 'Appointment'),
        body: RefreshIndicator(
          color: accent.color,
          onRefresh: () => context.read<AppointmentProvider>().loadAppointments(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              AppEntrance(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: status.background, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(status.icon, size: 22, color: status.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: status.color),
                            ),
                            if (line.isNotEmpty)
                              Text(line, style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppEntrance(
                index: 1,
                child: AppCard(
                  onTap: context.read<DoctorProvider>().findById(a.doctorId) == null
                      ? null
                      : () => _push(DoctorDetailScreen(doctorId: a.doctorId)),
                  child: Row(
                    children: [
                      AppAvatar(name: a.doctorName, imageUrl: a.imageUrl, size: 50, radius: 15, color: accent.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.doctorName,
                              style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                            ),
                            Text(a.specialty, style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (active || a.status == 'completed')
                        IconButton.filledTonal(
                          tooltip: 'Message',
                          onPressed: () => _chat(a),
                          style: IconButton.styleFrom(backgroundColor: accent.veryLight, foregroundColor: accent.color),
                          icon: const Icon(LucideIcons.messageCircle, size: 19),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppEntrance(
                index: 2,
                child: AppCard(
                  child: Column(
                    children: [
                      _Row(LucideIcons.calendarDays, DateFormat('EEEE, d MMMM y').format(a.dateTime)),
                      _Row(LucideIcons.clock, '${DateFormat('h:mm a').format(a.dateTime)} · ${a.duration} min'),
                      _Row(visitIcon, visitLabel),
                      if (a.appointmentType == 'clinic' && (a.clinicName.isNotEmpty || a.clinicAddress.isNotEmpty))
                        _Row(
                          LucideIcons.mapPin,
                          [a.clinicName, a.clinicAddress].where((e) => e.isNotEmpty).join('\n'),
                          trailing: TextButton(onPressed: () => _directions(a), child: const Text('Directions')),
                        ),
                      if (a.appointmentType == 'home' && a.visitAddress.isNotEmpty)
                        _Row(LucideIcons.mapPin, a.visitAddress),
                      if (a.rescheduleCount > 0)
                        _Row(LucideIcons.calendarClock, 'Rescheduled ${a.rescheduleCount} of 2 times'),
                    ],
                  ),
                ),
              ),
              if (a.symptomList.isNotEmpty || (a.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reason for visit', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      if (a.symptomList.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in a.symptomList)
                              AppStatusPill(text: s, color: AppColors.textPrimary, background: AppColors.panel),
                          ],
                        ),
                      ],
                      if ((a.reason ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(a.reason!, style: AppType.sans(fontSize: AppType.body, height: 1.45, color: AppColors.textPrimary)),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Consultation fee', style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                          Text(
                            a.totalAmount > 0 ? appRupees(a.totalAmount) : 'Free',
                            style: AppType.sans(fontSize: AppType.figure, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                          ),
                        ],
                      ),
                    ),
                    if (a.totalAmount > 0) PatientStatus.of(a.paymentStatus == 'pending' ? 'payment_pending' : a.paymentStatus).pill(),
                  ],
                ),
              ),
              if (a.prescriptionId != null && a.prescriptionId!.isNotEmpty) ...[
                const SizedBox(height: 14),
                AppCard(
                  onTap: () => _push(PrescriptionDetailsScreen(prescriptionId: a.prescriptionId!)),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: AppColors.brandVeryLight, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(LucideIcons.fileText, size: 19, color: AppColors.brand),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'View prescription',
                          style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ..._actions(a),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(Appointment a) {
    final out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(const SizedBox(height: 10));
      out.add(w);
    }

    if (!a.isTerminal) {
      if (a.isVideo) {
        add(AppButton(
          label: a.paymentRequired ? 'Pay and prepare call' : 'Open video consultation',
          icon: LucideIcons.video,
          onPressed: () => _push(ConsultationScreen(appointment: a)),
        ));
      } else if (a.totalAmount > 0 && !a.isPaid) {
        add(AppButton(
          label: 'Pay ${appRupees(a.totalAmount)} now',
          icon: LucideIcons.creditCard,
          onPressed: () => _push(PaymentCheckoutScreen(
            entityType: 'appointment',
            entityId: a.id,
            title: 'Consultation with ${a.doctorName}',
            expectedAmount: a.totalAmount,
          )),
        ));
      }
      if (a.canReschedule) {
        add(AppSecondaryButton(
          label: 'Reschedule',
          icon: LucideIcons.calendarClock,
          onPressed: () => _push(RescheduleAppointmentScreen(appointment: a)),
        ));
      }
      add(TextButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          if (await showCancelAppointmentSheet(context, a)) {
            messenger.showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
          }
        },
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        child: const Text('Cancel appointment'),
      ));
    } else if (a.status == 'completed' && _reviewed == false) {
      add(AppSecondaryButton(
        label: 'Rate this visit',
        icon: LucideIcons.star,
        onPressed: () async {
          if (await showReviewSheet(context, a)) setState(() => _reviewed = true);
        },
      ));
    }
    return out;
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  const _Row(this.icon, this.text, {this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: ModuleAccent.of(context).color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: AppType.sans(fontSize: AppType.body + 0.5, height: 1.4, color: AppColors.textPrimary)),
        ),
        ?trailing,
      ],
    ),
  );
}
