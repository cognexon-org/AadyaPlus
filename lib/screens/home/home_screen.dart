import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../models/appointment.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/lab_test_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pharmacy_provider.dart';
import '../appointments/appointment_details_screen.dart';
import '../appointments/consultation_screen.dart';
import '../chat/chat_list_screen.dart';
import '../doctors/doctor_detail_screen.dart';
import '../doctors/doctor_list_screen.dart';
import '../lab_tests/lab_test_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pathology/diagnostic_order_details_screen.dart';
import '../payments/payments_screen.dart';
import '../pharmacy/pharmacy_order_details_screen.dart';
import '../pharmacy/pharmacy_screen.dart';
import '../physiotherapy/physiotherapy_screen.dart';
import '../prescriptions/prescriptions_screen.dart';
import '../search/search_screen.dart';
import 'dashboard_screen.dart';
import 'home_carousel.dart';

/// Home: what's next for the patient, every service one tap away, orders
/// in progress, and the doctors and physios in the directory. Everything
/// shown comes from the backend; a section with nothing real to show is
/// left out rather than filled with samples.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LocationProvider>().locate();
      context.read<AppointmentProvider>().loadAppointments();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<AppointmentProvider>().loadAppointments(),
      context.read<DoctorProvider>().refreshDoctors(),
      context.read<PharmacyProvider>().loadOrders(),
      context.read<LabTestProvider>().loadOrders(),
      context.read<NotificationProvider>().loadNotifications(silent: true),
    ]);
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(AppPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(onOpen: _push)),
              SliverToBoxAdapter(
                child: AppEntrance(
                  index: 1,
                  child: _SearchBar(onTap: () => _push(const SearchScreen())),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: AppEntrance(
                  index: 2,
                  child: HeroCarousel(
                    slides: [
                      HeroSlide(
                        tag: 'Video consult',
                        tagIcon: LucideIcons.video,
                        title: 'Consult a doctor from home',
                        body: 'Verified doctors on video. Prescription in the app.',
                        cta: 'Consult now',
                        art: HeroArt.video,
                        gradient: [const Color(0xFF2CC2B6), ModuleAccent.doctor.color],
                        onTap: () => _push(const DoctorListScreen(visit: 'video')),
                      ),
                      HeroSlide(
                        tag: 'Lab tests',
                        tagIcon: LucideIcons.flaskConical,
                        title: 'Lab tests at your doorstep',
                        body: 'Sample taken at home. Reports right here.',
                        cta: 'Book a test',
                        art: HeroArt.lab,
                        gradient: [const Color(0xFFC46AD6), ModuleAccent.lab.color],
                        onTap: () => _push(const LabTestScreen()),
                      ),
                      HeroSlide(
                        tag: 'Medicines',
                        tagIcon: LucideIcons.pill,
                        title: 'Medicines, delivered home',
                        body: 'From pharmacies near you, tracked to your door.',
                        cta: 'Order now',
                        art: HeroArt.delivery,
                        gradient: [const Color(0xFF34C77B), ModuleAccent.pharmacy.color],
                        onTap: () => DashboardScreen.goTo(2),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(
                child: AppEntrance(index: 3, child: _UpNext(onOpen: _push)),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: AppEntrance(index: 4, child: _Services(onOpen: _push)),
              ),
              SliverToBoxAdapter(child: _InProgress(onOpen: _push)),
              SliverToBoxAdapter(
                child: _ProfessionalStrip(
                  type: 'doctor',
                  title: 'Top doctors',
                  accent: ModuleAccent.doctor,
                  onSeeAll: () => _push(const DoctorListScreen()),
                  onOpen: (d) => _push(DoctorDetailScreen(doctorId: d.id)),
                ),
              ),
              SliverToBoxAdapter(
                child: _ProfessionalStrip(
                  type: 'physio',
                  title: 'Physiotherapists',
                  accent: ModuleAccent.physio,
                  onSeeAll: () => _push(const PhysiotherapyScreen()),
                  onOpen: (d) => _push(DoctorDetailScreen(doctorId: d.id)),
                ),
              ),
              SliverToBoxAdapter(child: _HealthLinks(onOpen: _push)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.of(context).padding.bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Header ───────────────────────────

class _Header extends StatelessWidget {
  final void Function(Widget) onOpen;
  const _Header({required this.onOpen});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final unread = context.watch<NotificationProvider>().unreadCount;
    final location = context.watch<LocationProvider>();
    final first = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 14, 14),
        child: AppEntrance(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppPressable(
                    onTap: () => DashboardScreen.goTo(4),
                    semanticLabel: 'Your profile',
                    child: AppAvatar(
                      name: user?.name ?? '',
                      imageUrl: user?.profileImage,
                      size: 44,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: AppType.sans(
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          first.isEmpty ? 'Welcome' : first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundAction(
                    icon: LucideIcons.bell,
                    badge: unread,
                    label: 'Notifications',
                    onTap: () => onOpen(const NotificationsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppPressable(
                onTap: () => context.read<LocationProvider>().locate(ask: true),
                semanticLabel: 'Update location',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    location.locating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppColors.brand,
                            ),
                          )
                        : const Icon(
                            LucideIcons.mapPin,
                            size: 15,
                            color: AppColors.brand,
                          ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 100,
                      ),
                      child: Text(
                        location.label ??
                            (location.locating
                                ? 'Finding your location…'
                                : location.problem ?? 'Set your location'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(
                          fontSize: AppType.body,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      LucideIcons.chevronDown,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final int badge;
  final String label;
  final VoidCallback onTap;
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    semanticLabel: badge > 0 ? '$label, $badge unread' : label,
    child: SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: 20, color: AppColors.textStrong),
          ),
          if (badge > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.panel, width: 2),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: AppType.sans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: AppPressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: 'Search doctors and specialties',
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.search,
              size: 19,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search doctors, specialties, clinics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(
                  fontSize: AppType.body + 0.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────── Up next ───────────────────────────

class _UpNext extends StatelessWidget {
  final void Function(Widget) onOpen;
  const _UpNext({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>();
    final upcoming = appointments.getUpcomingAppointments();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedSwitcher(
        duration: AppMotion.medium,
        child: upcoming.isNotEmpty
            ? _AppointmentHero(
                key: ValueKey(upcoming.first.id),
                appointment: upcoming.first,
                more: upcoming.length - 1,
                onOpen: onOpen,
              )
            : _CareHero(
                key: const ValueKey('care'),
                onBook: () => onOpen(const DoctorListScreen()),
              ),
      ),
    );
  }
}

class _AppointmentHero extends StatelessWidget {
  final Appointment appointment;
  final int more;
  final void Function(Widget) onOpen;
  const _AppointmentHero({
    super.key,
    required this.appointment,
    required this.more,
    required this.onOpen,
  });

  IconData get _typeIcon => switch (appointment.appointmentType.toLowerCase()) {
    'video' => LucideIcons.video,
    'home' => LucideIcons.house,
    _ => LucideIcons.building2,
  };

  String get _typeLabel => switch (appointment.appointmentType.toLowerCase()) {
    'video' => 'Video call',
    'home' => 'Home visit',
    _ => 'Clinic visit',
  };

  @override
  Widget build(BuildContext context) {
    final physio = appointment.professionalType == 'physio';
    final accent = physio ? ModuleAccent.physio : ModuleAccent.doctor;
    final status = PatientStatus.of(appointment.status);
    final soon = appointment.dateTime.difference(DateTime.now()).inMinutes <= 15;
    final d = appointment.dateTime;
    return AppPressable(
      onTap: () => onOpen(AppointmentDetailsScreen(appointment: appointment)),
      scale: 0.985,
      child: ClipPath(
        clipper: _TicketClipper(notchY: 104),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          // The outline sits over the tinted header so it shows all round.
          foregroundDecoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Who.
              Container(
                height: 104,
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent.veryLight, Colors.white],
                  ),
                ),
                child: Row(
                  children: [
                    AppAvatar(name: appointment.doctorName, imageUrl: appointment.imageUrl, size: 56, radius: 18, color: accent.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                more > 0 ? 'Up next  ·  +$more more' : 'Up next',
                                style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: accent.color),
                              ),
                              const Spacer(),
                              status.pill(icon: false),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            appointment.doctorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(fontSize: AppType.title + 2, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textStrong),
                          ),
                          Text(
                            appointment.specialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // The tear line.
              SizedBox(height: 1, width: double.infinity, child: CustomPaint(painter: _DashPainter())),
              // When and how.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    _TicketFact(label: _dayLabel(d), value: DateFormat('h:mm a').format(d)),
                    Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 14), color: AppColors.border),
                    _TicketFact(label: 'Visit', value: _typeLabel, icon: _typeIcon, tint: accent.color),
                    const Spacer(),
                    if (appointment.isVideo) ...[
                      if (soon && !appointment.paymentRequired) ...[const AppPulse(color: AppColors.health), const SizedBox(width: 8)],
                      _SmallButton(
                        label: appointment.paymentRequired ? 'Pay' : 'Join',
                        icon: appointment.paymentRequired ? LucideIcons.creditCard : LucideIcons.video,
                        onTap: () => onOpen(ConsultationScreen(appointment: appointment)),
                      ),
                    ] else
                      Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }
}

class _TicketFact extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? tint;
  const _TicketFact({required this.label, required this.value, this.icon, this.tint});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: tint), const SizedBox(width: 4)],
          Text(value, style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
        ],
      ),
    ],
  );
}

/// A rounded card with a half-circle notch bitten from each side at
/// [notchY] — the perforation of a ticket.
class _TicketClipper extends CustomClipper<Path> {
  final double notchY;
  const _TicketClipper({required this.notchY});

  @override
  Path getClip(Size s) {
    const r = 9.0;
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(22)));
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(s.width, notchY), radius: r));
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  bool shouldReclip(_TicketClipper old) => old.notchY != notchY;
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1.2;
    for (var x = 14.0; x < s.width - 14; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4.5, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.sans(
                fontSize: AppType.body,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shown when nothing is booked: an invitation, not a sample appointment.
class _CareHero extends StatelessWidget {
  final VoidCallback onBook;
  const _CareHero({super.key, required this.onBook});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE6F4FC), Color(0xFFF5FAFE)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.brandLight),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How are you feeling today?',
                style: AppType.sans(
                  fontSize: AppType.title + 2,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textStrong,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Book a clinic visit or a video call with a verified doctor.',
                style: AppType.sans(
                  fontSize: AppType.small,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              _SmallButton(
                label: 'Book a consultation',
                icon: LucideIcons.calendarPlus,
                onTap: onBook,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const AppIllustration(
          Illustrations.medicalCare,
          height: 96,
          float: true,
        ),
      ],
    ),
  );
}

// ─────────────────────────── Services ───────────────────────────

class _Service {
  final IconData icon;
  final String label;
  final String caption;
  final ModuleAccent accent;
  final Widget Function() screen;
  final bool tab;
  const _Service(
    this.icon,
    this.label,
    this.caption,
    this.accent,
    this.screen, {
    this.tab = false,
  });
}

class _Services extends StatelessWidget {
  final void Function(Widget) onOpen;
  const _Services({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final services = [
      _Service(
        LucideIcons.stethoscope,
        'Doctors',
        'Clinic visits',
        ModuleAccent.doctor,
        () => const DoctorListScreen(),
      ),
      _Service(
        LucideIcons.video,
        'Video call',
        'From home',
        ModuleAccent.doctor,
        () => const DoctorListScreen(visit: 'video'),
      ),
      _Service(
        LucideIcons.flaskConical,
        'Lab tests',
        'Home pickup',
        ModuleAccent.lab,
        () => const LabTestScreen(),
      ),
      _Service(
        LucideIcons.pill,
        'Medicines',
        'Delivered',
        ModuleAccent.pharmacy,
        () => const PharmacyScreen(),
        tab: true,
      ),
      _Service(
        LucideIcons.activity,
        'Physio',
        'Home & clinic',
        ModuleAccent.physio,
        () => const PhysiotherapyScreen(),
      ),
      _Service(
        LucideIcons.folderHeart,
        'Records',
        'Reports',
        ModuleAccent.brand,
        () => const SizedBox(),
        tab: true,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Services'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 10.0;
              final w = (box.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (i, s) in services.indexed)
                    SizedBox(
                      width: w,
                      child: AppEntrance(
                        index: i,
                        child: _ServiceTile(
                          service: s,
                          onTap: () {
                            if (s.label == 'Medicines')
                              return DashboardScreen.goTo(2);
                            if (s.label == 'Records')
                              return DashboardScreen.goTo(3);
                            onOpen(s.screen());
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final _Service service;
  final VoidCallback onTap;
  const _ServiceTile({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    semanticLabel: service.label,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
      decoration: BoxDecoration(
        color: service.accent.veryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(service.icon, size: 19, color: service.accent.color),
          ),
          const SizedBox(height: 12),
          Text(
            service.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(
              fontSize: AppType.body,
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            service.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(
              fontSize: AppType.micro + 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────── In progress ───────────────────────────

class _Active {
  final IconData icon;
  final ModuleAccent accent;
  final String title;
  final String subtitle;
  final String status;
  final Widget screen;
  const _Active(
    this.icon,
    this.accent,
    this.title,
    this.subtitle,
    this.status,
    this.screen,
  );
}

class _InProgress extends StatelessWidget {
  final void Function(Widget) onOpen;
  const _InProgress({required this.onOpen});

  static const _pharmacyDone = ['delivered', 'cancelled', 'returned'];
  static const _labDone = ['completed', 'cancelled'];

  @override
  Widget build(BuildContext context) {
    final pharmacy = context.watch<PharmacyProvider>().orders;
    final lab = context.watch<LabTestProvider>().orders;
    final items = <_Active>[
      for (final o in pharmacy)
        if (!_pharmacyDone.contains(o['orderStatus']))
          _Active(
            LucideIcons.pill,
            ModuleAccent.pharmacy,
            mapOf(o['storeId'])['name']?.toString() ?? 'Medicine order',
            '${mapsOf(o['items']).length} item${mapsOf(o['items']).length == 1 ? '' : 's'} · ${appRupees(o['totalAmount'])}',
            (o['orderStatus'] ?? '').toString(),
            PharmacyOrderDetailsScreen(orderId: idOf(o)),
          ),
      for (final o in lab)
        if (!_labDone.contains(o['status']))
          _Active(
            LucideIcons.flaskConical,
            ModuleAccent.lab,
            _labTitle(o),
            mapOf(o['pathologyId'])['labName']?.toString() ?? 'Lab test',
            (o['status'] ?? '').toString(),
            DiagnosticOrderDetailsScreen(orderId: idOf(o)),
          ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'In progress'),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => AppEntrance(
                index: i,
                child: _ActiveCard(
                  item: items[i],
                  onTap: () => onOpen(items[i].screen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _labTitle(Map<String, dynamic> o) {
    final packages = mapsOf(o['packages']);
    final tests = mapsOf(o['tests']);
    if (packages.isNotEmpty)
      return (packages.first['packageName'] ?? 'Health package').toString();
    if (tests.isEmpty) return 'Lab test';
    final first = (tests.first['testName'] ?? 'Lab test').toString();
    return tests.length > 1 ? '$first +${tests.length - 1}' : first;
  }
}

class _ActiveCard extends StatelessWidget {
  final _Active item;
  final VoidCallback onTap;
  const _ActiveCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = PatientStatus.of(item.status);
    return AppPressable(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.accent.veryLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, size: 20, color: item.accent.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: AppType.body,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: AppType.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  status.pill(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Professionals ───────────────────────────

class _ProfessionalStrip extends StatelessWidget {
  final String type;
  final String title;
  final ModuleAccent accent;
  final VoidCallback onSeeAll;
  final void Function(Doctor) onOpen;
  const _ProfessionalStrip({
    required this.type,
    required this.title,
    required this.accent,
    required this.onSeeAll,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DoctorProvider>();
    final list = directory.query(type: type).take(10).toList();
    if (list.isEmpty && !directory.isLoading) return const SizedBox.shrink();
    return ModuleTheme(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: title,
              action: 'See all',
              onAction: onSeeAll,
            ),
            SizedBox(
              height: 172,
              child: list.isEmpty
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: const [
                        AppShimmer(
                          child: Row(
                            children: [
                              AppSkeletonBlock(
                                width: 150,
                                height: 172,
                                radius: 18,
                              ),
                              SizedBox(width: 10),
                              AppSkeletonBlock(
                                width: 150,
                                height: 172,
                                radius: 18,
                              ),
                              SizedBox(width: 10),
                              AppSkeletonBlock(
                                width: 150,
                                height: 172,
                                radius: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => AppEntrance(
                        index: i,
                        child: _ProfessionalCard(
                          doctor: list[i],
                          accent: accent,
                          onTap: () => onOpen(list[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final Doctor doctor;
  final ModuleAccent accent;
  final VoidCallback onTap;
  const _ProfessionalCard({
    required this.doctor,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    semanticLabel: '${doctor.name}, ${doctor.specialty}',
    child: Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppAvatar(
                name: doctor.name,
                imageUrl: doctor.imageUrl,
                size: 60,
                radius: 18,
                color: accent.color,
              ),
              if (doctor.videoEnabled)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Icon(
                      LucideIcons.video,
                      size: 11,
                      color: accent.color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            doctor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(
              fontSize: AppType.body,
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            doctor.specialty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(
              fontSize: AppType.caption,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              if (doctor.reviews > 0) ...[
                const Icon(
                  LucideIcons.star,
                  size: 13,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 3),
                Text(
                  doctor.rating.toStringAsFixed(1),
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ] else if (doctor.experience > 0)
                Text(
                  '${doctor.experience} yrs exp',
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              const Spacer(),
              if (doctor.fromFee > 0)
                Text(
                  appRupees(doctor.fromFee),
                  style: AppType.sans(
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w800,
                    color: accent.color,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────── Health links ───────────────────────────

class _HealthLinks extends StatelessWidget {
  final void Function(Widget) onOpen;
  const _HealthLinks({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final links = [
      (
        LucideIcons.fileText,
        'Prescriptions',
        () => onOpen(const PrescriptionsScreen()),
      ),
      (
        LucideIcons.messagesSquare,
        'Messages',
        () => onOpen(const ChatListScreen()),
      ),
      (
        LucideIcons.receiptIndianRupee,
        'Payments',
        () => onOpen(const PaymentsScreen()),
      ),
      (LucideIcons.calendarDays, 'Bookings', () => DashboardScreen.goTo(1)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Your health'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Column(
                children: [
                  for (final (i, (icon, label, onTap)) in links.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 60),
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(i == 0 ? 18 : 0),
                        bottom: Radius.circular(i == links.length - 1 ? 18 : 0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.brandVeryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                size: 17,
                                color: AppColors.brand,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: AppType.sans(
                                  fontSize: AppType.body + 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textStrong,
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
