import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/slot_picker.dart';

/// Move an appointment to another free slot with the same professional and
/// the same kind of visit.
class RescheduleAppointmentScreen extends StatefulWidget {
  final Appointment appointment;
  const RescheduleAppointmentScreen({super.key, required this.appointment});

  @override
  State<RescheduleAppointmentScreen> createState() => _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState extends State<RescheduleAppointmentScreen> {
  DateTime? _when;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  int _reload = 0;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_when == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppointmentProvider>().reschedule(widget.appointment.id, _when!, reason: _reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to ${DateFormat('EEE, d MMM · h:mm a').format(_when!)}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _reload++;
          _when = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final accent = a.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;
    final left = 2 - a.rescheduleCount;
    return ModuleTheme(
      accent: accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: 'Reschedule', subtitle: a.doctorName),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendarClock, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Currently', style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                        Text(
                          DateFormat('EEE, d MMM · h:mm a').format(a.dateTime),
                          style: AppType.sans(
                            fontSize: AppType.body + 0.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textStrong,
                            decoration: _when != null ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$left change${left == 1 ? '' : 's'} left',
                    style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 10),
              child: Text(
                'Pick a new day and time',
                style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
              ),
            ),
            SlotPicker(
              key: ValueKey(_reload),
              professionalId: a.doctorId,
              professionalType: a.professionalType,
              visit: a.appointmentType,
              onChanged: (at) => WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && at != _when) setState(() => _when = at);
              }),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: '',
              hint: 'Reason (optional)',
              controller: _reason,
              textCapitalization: TextCapitalization.sentences,
              margin: EdgeInsets.zero,
            ),
            if (_error != null) ...[const SizedBox(height: 12), AuthNote.error(_error!)],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: AppButton(
              label: _when == null ? 'Choose a new time' : 'Move to ${DateFormat('EEE d MMM, h:mm a').format(_when!)}',
              loading: _busy,
              onPressed: _when == null ? null : _save,
            ),
          ),
        ),
      ),
    );
  }
}
