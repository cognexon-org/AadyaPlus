import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/pharmacy_provider.dart';
import '../appointments/appointments_screen.dart';
import '../health_records/health_records_screen.dart';
import '../pharmacy/pharmacy_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// The signed-in app: five tabs, each kept alive so switching back finds it
/// where it was left.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static final _tab = ValueNotifier<int>(0);

  /// Switches tab from anywhere inside the app (Home's shortcuts use it).
  static void goTo(int index) => _tab.value = index;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _built = <int>{0};
  LocationProvider? _location;

  static const _pages = <Widget>[
    HomeScreen(),
    AppointmentsScreen(),
    PharmacyScreen(),
    HealthRecordsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    DashboardScreen._tab.value = 0;
    DashboardScreen._tab.addListener(_onTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Distances to clinics follow wherever the patient is.
    final location = context.read<LocationProvider>();
    if (!identical(location, _location)) {
      _location?.removeListener(_syncLocation);
      _location = location..addListener(_syncLocation);
      _syncLocation();
    }
  }

  void _syncLocation() {
    final l = _location;
    if (l == null || !l.hasPosition) return;
    final doctors = context.read<DoctorProvider>();
    if (doctors.userLat == l.lat && doctors.userLng == l.lng) return;
    doctors.setUserLocation(l.lat!, l.lng!);
  }

  void _onTab() => setState(() => _built.add(DashboardScreen._tab.value));

  @override
  void dispose() {
    DashboardScreen._tab.removeListener(_onTab);
    _location?.removeListener(_syncLocation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = DashboardScreen._tab.value;
    final cart = context.select<PharmacyProvider, int>((p) => p.cartCount);
    return PopScope(
      // Back from another tab returns to Home before leaving the app.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) DashboardScreen.goTo(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              // A tab is built the first time it's opened, then kept.
              _built.contains(i) ? _pages[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: AppNavBar(
          currentIndex: index,
          onTap: (i) {
            if (i == index) return;
            HapticFeedback.selectionClick();
            DashboardScreen.goTo(i);
          },
          items: [
            const AppNavItem(LucideIcons.house, 'Home'),
            const AppNavItem(LucideIcons.calendarDays, 'Bookings'),
            AppNavItem(LucideIcons.pill, 'Medicines', badge: cart),
            const AppNavItem(LucideIcons.folderHeart, 'Records'),
            const AppNavItem(LucideIcons.circleUserRound, 'Profile'),
          ],
        ),
      ),
    );
  }
}
