import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../core/ui/app_ui.dart';
import '../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../services/feedback_service.dart';

Widget _sheetTitle(String title, String? subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
    ),
    if (subtitle != null) ...[
      const SizedBox(height: 4),
      Text(subtitle, style: AppType.sans(fontSize: AppType.body, height: 1.4, color: AppColors.textSecondary)),
    ],
  ],
);

/// Asks why, then cancels. Returns true once cancelled.
Future<bool> showCancelAppointmentSheet(BuildContext context, Appointment appointment) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CancelSheet(appointment: appointment),
  );
  return done == true;
}

class _CancelSheet extends StatefulWidget {
  final Appointment appointment;
  const _CancelSheet({required this.appointment});

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  static const _reasons = [
    'Feeling better',
    'Can’t make it at this time',
    'Booked by mistake',
    'Found another doctor',
    'Other',
  ];
  String? _reason;
  final _other = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final reason = _reason == 'Other' ? _other.text.trim() : _reason;
    if (reason == null || reason.isEmpty) {
      setState(() => _error = 'Tell us why you’re cancelling');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppointmentProvider>().cancelAppointment(widget.appointment.id, reason: reason);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').replaceFirst('Cancellation error: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle(
            'Cancel this appointment?',
            widget.appointment.isPaid && widget.appointment.totalAmount > 0
                ? 'Any refund due goes back to how you paid. Late cancellations may have a fee.'
                : 'The ${widget.appointment.isPhysio ? 'physio' : 'doctor'} will be told straight away.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _reasons)
                AppFilterChip(label: r, selected: _reason == r, onTap: () => setState(() => _reason = r)),
            ],
          ),
          if (_reason == 'Other') ...[
            const SizedBox(height: 12),
            AppTextField(label: '', hint: 'What happened?', controller: _other, margin: EdgeInsets.zero),
          ],
          if (_error != null) ...[const SizedBox(height: 12), AuthNote.error(_error!)],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _cancel,
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Cancel appointment'),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
        ],
      ),
    ),
  );
}

/// Star rating and a few words about a completed visit. Returns true once sent.
Future<bool> showReviewSheet(BuildContext context, Appointment appointment) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReviewSheet(appointment: appointment),
  );
  return done == true;
}

class _ReviewSheet extends StatefulWidget {
  final Appointment appointment;
  const _ReviewSheet({required this.appointment});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  bool _recommend = true;
  final _strengths = <String>{};
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _praise = ['Listened well', 'Explained clearly', 'On time', 'Friendly', 'Helpful advice'];
  static const _words = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0) {
      setState(() => _error = 'Choose a star rating');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FeedbackService.instance.submit(
        appointmentId: widget.appointment.id,
        rating: _rating,
        comments: _comment.text.trim(),
        wouldRecommend: _recommend,
        strengths: _strengths.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetTitle('How was your visit?', 'With ${widget.appointment.doctorName}'),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  AppPressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _rating = i;
                        _error = null;
                      });
                    },
                    semanticLabel: '$i star${i == 1 ? '' : 's'}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedScale(
                        duration: AppMotion.fast,
                        scale: i <= _rating ? 1.1 : 1,
                        child: Icon(
                          LucideIcons.star,
                          size: 38,
                          color: i <= _rating ? const Color(0xFFF59E0B) : AppColors.borderStrong,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _words[_rating],
              textAlign: TextAlign.center,
              style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final p in _praise)
                  AppFilterChip(
                    label: p,
                    selected: _strengths.contains(p),
                    onTap: () => setState(() => _strengths.contains(p) ? _strengths.remove(p) : _strengths.add(p)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: '',
              hint: 'Share more about your experience (optional)',
              controller: _comment,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 6),
            AppSwitchRow(
              label: 'I’d recommend them',
              value: _recommend,
              onChanged: (v) => setState(() => _recommend = v),
              margin: EdgeInsets.zero,
            ),
            if (_error != null) ...[const SizedBox(height: 8), AuthNote.error(_error!)],
            const SizedBox(height: 14),
            AppButton(label: 'Send review', loading: _busy, onPressed: _send),
          ],
        ),
      ),
    ),
  );
}
