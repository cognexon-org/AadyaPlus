import 'package:flutter/material.dart';

/// Retained only for compatibility with older widget imports.
/// Medicine discovery/cart now lives in PharmacyProvider and the /epharmacy API.
class MedicineProvider with ChangeNotifier {
  bool get isLoading => false;
}
