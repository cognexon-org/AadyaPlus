import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/providers/chat_provider.dart';
import 'package:aadya_plus/providers/doctor_provider.dart';
import 'package:aadya_plus/providers/lab_test_provider.dart';
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
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(
    aadyaFirebaseMessagingBackgroundHandler,
  );
  runApp(const MyApp());
}

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
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => LabTestProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PharmacyProvider()),
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
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
        theme: ThemeData(
          primaryColor: const Color(0xFF10B8B1),
          primarySwatch: Colors.teal,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
          ),
        ),
        home: const AppWrapper(),
      ),
    );
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      NotificationNavigationService.instance.setAuthenticatedReady(false);
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
