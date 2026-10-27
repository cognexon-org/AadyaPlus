import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ui/app_ui.dart';
import '../models/appointment.dart';

/// What a card's action row offers for one appointment.
enum AppointmentAction { join, pay, reschedule, cancel, prescription, review, bookAgain }

/// An appointment in the bookings list: when, with whom, how, its status,
/// and the actions that make sense for it right now.
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool reviewed;
  final VoidCallback onTap;
  final ValueChanged<AppointmentAction> onAction;
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    required this.onAction,
    this.reviewed = false,
  });

  List<(AppointmentAction, String, IconData)> get _actions {
    final a = appointment;
    final status = a.status.toLowerCase();
    if (status == 'completed') {
      return [
        if (a.prescriptionId != null && a.prescriptionId!.isNotEmpty)
          (AppointmentAction.prescription, 'Prescription', LucideIcons.fileText),
        if (!reviewed) (AppointmentAction.review, 'Rate visit', LucideIcons.star),
        (AppointmentAction.bookAgain, 'Book again', LucideIcons.rotateCw),
      ];
    }
    if (a.isTerminal) return [(AppointmentAction.bookAgain, 'Book again', LucideIcons.rotateCw)];
    return [
      if (a.isVideo)
        a.paymentRequired
            ? (AppointmentAction.pay, 'Pay', LucideIcons.creditCard)
            : (AppointmentAction.join, 'Join', LucideIcons.video),
      if (a.canReschedule) (AppointmentAction.reschedule, 'Reschedule', LucideIcons.calendarClock),
      (AppointmentAction.cancel, 'Cancel', LucideIcons.x),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final accent = a.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;
    final status = PatientStatus.of(a.status);
    final (visitIcon, visitLabel) = switch (a.appointmentType.toLowerCase()) {
      'video' => (LucideIcons.video, 'Video call'),
      'home' => (LucideIcons.house, 'Home visit'),
      _ => (LucideIcons.building2, a.clinicName.isNotEmpty ? a.clinicName : 'Clinic visit'),
    };
    final actions = _actions;
    return AppPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateBlock(date: a.dateTime, accent: accent, muted: a.isTerminal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.doctorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.sans(
                                  fontSize: AppType.title,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textStrong,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            status.pill(icon: false),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(LucideIcons.clock, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('h:mm a').format(a.dateTime),
                              style: AppType.sans(
                                fontSize: AppType.caption + 0.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(visitIcon, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                visitLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.sans(
                                  fontSize: AppType.caption + 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Container(
                height: 46,
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    for (final (i, (action, label, icon)) in actions.indexed) ...[
                      if (i > 0) Container(width: 1, height: 22, color: AppColors.border),
                      Expanded(
                        child: _ActionButton(
                          label: label,
                          icon: icon,
                          primary: action == AppointmentAction.join || action == AppointmentAction.pay,
                          danger: action == AppointmentAction.cancel,
                          accent: accent,
                          onTap: () => onAction(action),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final DateTime date;
  final ModuleAccent accent;
  final bool muted;
  const _DateBlock({required this.date, required this.accent, required this.muted});

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: muted ? AppColors.panel : accent.veryLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          DateFormat('MMM').format(date),
          style: AppType.sans(
            fontSize: AppType.caption,
            fontWeight: FontWeight.w700,
            color: muted ? AppColors.textSecondary : accent.color,
          ),
        ),
        Text(
          '${date.day}',
          style: AppType.sans(
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: muted ? AppColors.textSecondary : AppColors.textStrong,
          ),
        ),
        Text(
          DateFormat('EEE').format(date),
          style: AppType.sans(fontSize: AppType.micro, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final bool danger;
  final ModuleAccent accent;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.danger,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = primary ? accent.color : danger ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppType.sans(
                fontSize: AppType.small,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
