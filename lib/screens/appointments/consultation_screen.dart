import 'dart:async';

import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/models/consultation_session.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/screens/appointments/prescription_details_screen.dart';
import 'package:aadya_plus/screens/appointments/video_call_screen.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/services/consultation_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
        const SnackBar(content: Text('Please accept teleconsultation consent before check-in.')),
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

  Future<void> _join() async {
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'patient_waiting':
        return 'You are checked in';
      case 'professional_ready':
        return 'Doctor is ready';
      case 'in_progress':
        return 'Consultation in progress';
      case 'ended':
        return 'Consultation completed';
      case 'cancelled':
        return 'Consultation cancelled';
      case 'no_show':
        return 'Marked as no-show';
      default:
        return 'Scheduled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Consultation'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(onPressed: _loading ? null : () => _load(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: _buildContent(),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            Text(_error ?? 'Unable to load consultation', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final session = _snapshot!.session;
    final scheduled = session.scheduledAt ?? widget.appointment.dateTime;
    final clinical = session.clinicalSummary;

    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.appointment.doctorName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.appointment.specialty, style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w700)),
            const Divider(height: 28),
            _row(Icons.calendar_today_outlined, DateFormat('dd MMM yyyy, hh:mm a').format(scheduled)),
            const SizedBox(height: 10),
            _row(widget.appointment.isVideo ? Icons.videocam_outlined : Icons.local_hospital_outlined,
                widget.appointment.isVideo ? 'Video consultation' : widget.appointment.appointmentType),
            const SizedBox(height: 10),
            _row(Icons.info_outline, _statusLabel(session.status)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (session.paymentRequired)
        _card(
          color: Colors.orange.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Pay ₹${widget.appointment.totalAmount.toStringAsFixed(2)} before checking in to this video consultation.'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _actionBusy ? null : _pay,
                  child: const Text('Pay now'),
                ),
              ),
            ],
          ),
        )
      else if (!session.isEnded) ...[
        if (widget.appointment.isVideo && !session.isCheckedIn)
          _card(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consentChecked,
              onChanged: _actionBusy ? null : (value) => setState(() => _consentChecked = value == true),
              title: const Text('Teleconsultation consent', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('I consent to receiving this consultation by video and understand that clinical information will be handled as part of my AadyaMed record.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        if (session.canCheckIn && !session.isCheckedIn) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _actionBusy ? null : _checkIn,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('Check in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        if (session.isCheckedIn && !session.canJoin) ...[
          const SizedBox(height: 14),
          _card(
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('You are in the waiting room. This screen refreshes automatically while the professional prepares the consultation.')),
              ],
            ),
          ),
        ],
        if (session.canJoin) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _actionBusy ? null : _join,
              icon: const Icon(Icons.videocam),
              label: Text(session.isInProgress ? 'Join consultation' : 'Enter video room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
        if (!session.canCheckIn && !session.isCheckedIn) ...[
          const SizedBox(height: 14),
          _card(
            color: Colors.grey.shade100,
            child: Text(
              session.joinOpensAt != null
                  ? 'Check-in opens ${DateFormat('dd MMM, hh:mm a').format(session.joinOpensAt!)}.'
                  : 'Check-in is not open yet.',
            ),
          ),
        ],
      ],
      if (session.isEnded) ...[
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Consultation summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _summaryLine('Diagnosis', clinical?['diagnosis']),
              _summaryLine('Advice', clinical?['advice']),
              _summaryLine('Follow-up', clinical?['followUpNotes']),
            ],
          ),
        ),
        if (widget.appointment.prescriptionId != null && widget.appointment.prescriptionId!.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionDetailsScreen(prescriptionId: widget.appointment.prescriptionId!),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('View e-prescription'),
            ),
          ),
        ],
      ],
    ];
  }

  Widget _summaryLine(String label, dynamic value) {
    String text;
    if (value is List) {
      text = value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join(', ');
    } else {
      text = value?.toString() ?? '';
    }
    if (text.isEmpty) text = '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _card({required Widget child, Color color = Colors.white}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
