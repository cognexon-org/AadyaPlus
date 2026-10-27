import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/app_ui.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../home/dashboard_screen.dart';
import '../payments/payment_checkout_screen.dart';

/// After booking: what was booked, that the professional confirms it next,
/// and — when there's a fee — paying now (required before a video call).
class BookingConfirmedScreen extends StatefulWidget {
  final Doctor doctor;
  final BookingResult result;
  final DateTime when;
  final String visit;
  const BookingConfirmedScreen({
    super.key,
    required this.doctor,
    required this.result,
    required this.when,
    required this.visit,
  });

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> {
  bool _paid = false;

  bool get _needsPayment => widget.result.paymentRequired && widget.result.amount > 0 && !_paid;

  Future<void> _pay() async {
    final paid = await Navigator.of(context).push<bool>(
      AppPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          entityType: 'appointment',
          entityId: widget.result.appointmentId,
          title: 'Consultation with ${widget.doctor.name}',
          expectedAmount: widget.result.amount,
        ),
      ),
    );
    if (paid == true && mounted) setState(() => _paid = true);
  }

  void _done() {
    DashboardScreen.goTo(1);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.doctor.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;
    final (icon, label) = switch (widget.visit) {
      'video' => (LucideIcons.video, 'Video call'),
      'home' => (LucideIcons.house, 'Home visit'),
      _ => (LucideIcons.building2, 'Clinic visit'),
    };
    return ModuleTheme(
      accent: accent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _done();
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                const AppEntrance(
                  child: AppIllustration(Illustrations.booked, height: 170, float: true),
                ),
                const SizedBox(height: 24),
                AppEntrance(
                  index: 1,
                  child: Text(
                    _paid ? 'Booked and paid' : 'Booking requested',
                    textAlign: TextAlign.center,
                    style: AppType.sans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AppEntrance(
                  index: 1,
                  child: Text(
                    '${widget.doctor.name} will confirm shortly. We’ll notify you as soon as they do.',
                    textAlign: TextAlign.center,
                    style: AppType.sans(fontSize: AppType.body + 0.5, height: 1.45, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),
                AppEntrance(
                  index: 2,
                  child: AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppAvatar(
                              name: widget.doctor.name,
                              imageUrl: widget.doctor.imageUrl,
                              size: 44,
                              radius: 13,
                              color: accent.color,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.doctor.name,
                                    style: AppType.sans(
                                      fontSize: AppType.body + 1,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                  Text(
                                    widget.doctor.specialty,
                                    style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _Line(LucideIcons.calendarClock, DateFormat('EEEE, d MMMM · h:mm a').format(widget.when)),
                        _Line(icon, label),
                        _Line(
                          LucideIcons.wallet,
                          widget.result.amount <= 0
                              ? 'No fee'
                              : _paid
                              ? '${appRupees(widget.result.amount)} paid'
                              : '${appRupees(widget.result.amount)} · ${widget.visit == 'video' ? 'pay before the call' : 'pay now or at the visit'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_needsPayment) ...[
                  AppButton(
                    label: 'Pay ${appRupees(widget.result.amount)} now',
                    icon: LucideIcons.creditCard,
                    onPressed: _pay,
                  ),
                  const SizedBox(height: 10),
                  AppSecondaryButton(label: 'Go to my bookings', onPressed: _done),
                ] else
                  AppButton(label: 'Go to my bookings', onPressed: _done),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 16, color: ModuleAccent.of(context).color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppType.sans(
              fontSize: AppType.body,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
