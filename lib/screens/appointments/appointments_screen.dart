import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart' show MethodSwitch;
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../services/feedback_service.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/appointment_sheets.dart';
import '../doctors/doctor_detail_screen.dart';
import '../doctors/doctor_list_screen.dart';
import '../payments/payment_checkout_screen.dart';
import 'appointment_details_screen.dart';
import 'consultation_screen.dart';
import 'prescription_details_screen.dart';
import 'reschedule_appointment_screen.dart';

/// The Bookings tab: upcoming, past and cancelled appointments, each card
/// carrying the next useful action.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _tab = 0;
  Set<String> _reviewed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final provider = context.read<AppointmentProvider>();
    await Future.wait([
      provider.loadAppointments(),
      FeedbackService.instance.reviewedAppointmentIds().then((ids) {
        if (mounted) setState(() => _reviewed = ids);
      }).catchError((_) {}),
    ]);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(AppPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  Future<void> _act(Appointment a, AppointmentAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case AppointmentAction.join:
        await _open(ConsultationScreen(appointment: a));
      case AppointmentAction.pay:
        await _open(PaymentCheckoutScreen(
          entityType: 'appointment',
          entityId: a.id,
          title: 'Consultation with ${a.doctorName}',
          expectedAmount: a.totalAmount,
        ));
      case AppointmentAction.reschedule:
        await _open(RescheduleAppointmentScreen(appointment: a));
      case AppointmentAction.cancel:
        if (await showCancelAppointmentSheet(context, a)) {
          messenger.showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
          _refresh();
        }
      case AppointmentAction.prescription:
        await _open(PrescriptionDetailsScreen(prescriptionId: a.prescriptionId!));
      case AppointmentAction.review:
        if (await showReviewSheet(context, a)) {
          setState(() => _reviewed = {..._reviewed, a.id});
          messenger.showSnackBar(const SnackBar(content: Text('Thanks — your review was sent')));
        }
      case AppointmentAction.bookAgain:
        final doctor = context.read<DoctorProvider>().findById(a.doctorId);
        await _open(doctor != null ? DoctorDetailScreen(doctorId: doctor.id) : const DoctorListScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();
    final lists = [
      provider.getUpcomingAppointments(),
      provider.getPastAppointments(),
      provider.getCancelledAppointments(),
    ];
    final list = lists[_tab];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppTopBar(
        title: 'Bookings',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Book a consultation',
            icon: const Icon(LucideIcons.calendarPlus, size: 22),
            onPressed: () => _open(const DoctorListScreen()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: MethodSwitch(
              labels: [
                'Upcoming${lists[0].isEmpty ? '' : ' · ${lists[0].length}'}',
                'Past',
                'Cancelled',
              ],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _refresh,
              child: provider.isLoading && provider.appointments.isEmpty
                  ? const AppListSkeleton(count: 4)
                  : list.isEmpty
                  ? ListView(
                      children: [
                        if (provider.error != null && provider.appointments.isEmpty)
                          AppEmptyState(
                            illustration: Illustrations.offline,
                            title: 'Couldn’t load your bookings',
                            message: 'Check your connection and pull down to try again.',
                            actionLabel: 'Try again',
                            onAction: _refresh,
                          )
                        else
                          AppEmptyState(
                            illustration: Illustrations.emptyCalendar,
                            title: switch (_tab) {
                              0 => 'Nothing booked yet',
                              1 => 'No past visits',
                              _ => 'No cancellations',
                            },
                            message: _tab == 0
                                ? 'Book a clinic visit, a video call or a home visit in a minute.'
                                : null,
                            actionLabel: _tab == 0 ? 'Book a consultation' : null,
                            onAction: _tab == 0 ? () => _open(const DoctorListScreen()) : null,
                          ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => AppEntrance(
                        index: i.clamp(0, 6),
                        child: AppointmentCard(
                          appointment: list[i],
                          reviewed: _reviewed.contains(list[i].id),
                          onTap: () => _open(AppointmentDetailsScreen(appointment: list[i])),
                          onAction: (action) => _act(list[i], action),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
