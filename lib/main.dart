import 'package:aadya_plus/core/ui/app_ui.dart';
import 'package:aadya_plus/features/onboarding/intro_screen.dart';
import 'package:aadya_plus/features/onboarding/splash_screen.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/providers/chat_provider.dart';
import 'package:aadya_plus/providers/doctor_provider.dart';
import 'package:aadya_plus/providers/lab_test_provider.dart';
import 'package:aadya_plus/providers/location_provider.dart';
import 'package:aadya_plus/providers/notification_provider.dart';
import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/providers/prescription_provider.dart';
import 'package:aadya_plus/screens/auth/complete_patient_profile_screen.dart';
import 'package:aadya_plus/screens/auth/login_screen.dart';
import 'package:aadya_plus/screens/home/dashboard_screen.dart';
import 'package:aadya_plus/services/notification_navigation_service.dart';
import 'package:aadya_plus/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(
    aadyaFirebaseMessagingBackgroundHandler,
  );
  // Riverpod's root: modules move onto it one by one as they're rebuilt;
  // the existing Provider-based screens keep working alongside.
  runApp(const riverpod.ProviderScope(child: MyApp()));
}

/// Which account an account-scoped store was created for.
final Expando<String> _accountOf = Expando<String>('account');

/// A store that belongs to one signed-in account: a fresh instance is made
/// whenever the account changes (sign in, sign out, switch), so one
/// person's appointments, cart, orders or lab tests never show for the next
/// person on the same phone.
ChangeNotifierProxyProvider<AuthProvider, T> perAccount<T extends ChangeNotifier>(
  T Function() create,
) => ChangeNotifierProxyProvider<AuthProvider, T>(
  create: (_) => create(),
  update: (_, auth, previous) {
    final account = auth.isAuthenticated ? (auth.user?.id ?? '') : '';
    if (previous != null) {
      final owner = _accountOf[previous];
      if (owner == null || owner == account) {
        _accountOf[previous] = account;
        return previous;
      }
    }
    final fresh = create();
    _accountOf[fresh] = account;
    return fresh;
  },
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PushNotificationService.instance.initialize();
      await NotificationNavigationService.instance.drainPending();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // The directory is public, not personal.
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        perAccount(AppointmentProvider.new),
        perAccount(LabTestProvider.new),
        perAccount(ChatProvider.new),
        perAccount(PharmacyProvider.new),
        perAccount(PrescriptionProvider.new),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) {
            final provider = notifications ?? NotificationProvider();
            provider.setAuthenticated(auth.isAuthenticated);
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: NotificationNavigationService.navigatorKey,
        title: 'Aadya Plus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const LaunchGate(),
      ),
    );
  }
}

/// What opens at launch: the splash plays while the saved session is read,
/// then the walkthrough for someone new, then the app.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool _splashDone = false;
  bool? _introSeen;

  @override
  void initState() {
    super.initState();
    IntroScreen.hasBeenSeen().then((seen) {
      if (mounted) setState(() => _introSeen = seen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final Widget stage;
    if (!_splashDone || auth.isRestoring || _introSeen == null) {
      stage = SplashScreen(
        key: const ValueKey('splash'),
        onFinished: () => setState(() => _splashDone = true),
      );
    } else if (_introSeen == false && !auth.isAuthenticated) {
      stage = IntroScreen(
        key: const ValueKey('intro'),
        onDone: () => setState(() => _introSeen = true),
      );
    } else {
      stage = const AppWrapper(key: ValueKey('app'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 1.03, end: 1.0).animate(a),
          child: child,
        ),
      ),
      child: stage,
    );
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Only while the saved session is first read — not during sign-in,
    // which used to unmount the login screen and lose its error.
    if (authProvider.isRestoring) {
      return const Scaffold(body: AppLoading());
    }

    if (!authProvider.isAuthenticated) {
      NotificationNavigationService.instance.setAuthenticatedReady(false);
      // Signed out with screens still open on top (an appointment, an
      // order): close them so the login screen is what's showing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationNavigationService.navigatorKey.currentState?.popUntil(
          (route) => route.isFirst,
        );
      });
      return const LoginScreen();
    }

    if (authProvider.needsProfileCompletion) {
      NotificationNavigationService.instance.setAuthenticatedReady(false);
      return const CompletePatientProfileScreen();
    }

    NotificationNavigationService.instance.setAuthenticatedReady(true);
    return const DashboardScreen();
  }
}
