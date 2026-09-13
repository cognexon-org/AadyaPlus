import 'package:aadya_plus/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/providers/doctor_provider.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/providers/medicine_provider.dart';
import 'package:aadya_plus/providers/lab_test_provider.dart';
import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/providers/prescription_provider.dart';
import 'package:aadya_plus/providers/notification_provider.dart';
import 'package:aadya_plus/screens/auth/login_screen.dart';
import 'package:aadya_plus/screens/home/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DoctorProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => MedicineProvider()),
        ChangeNotifierProvider(create: (_) => LabTestProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PharmacyProvider()),
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
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

    return authProvider.isAuthenticated
        ? const DashboardScreen()
        : const LoginScreen();
  }
}
