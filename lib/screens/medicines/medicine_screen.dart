import 'package:aadya_plus/screens/pharmacy/pharmacy_screen.dart';
import 'package:flutter/material.dart';

/// The old mock medicine catalogue has been retired. Medicines are now sourced
/// from the selected pharmacy branch through the /epharmacy catalog.
class MedicineScreen extends StatelessWidget {
  const MedicineScreen({super.key});
  @override
  Widget build(BuildContext context) => const PharmacyScreen();
}
