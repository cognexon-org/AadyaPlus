import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';

class PrescriptionDetailsScreen extends StatefulWidget {
  final String prescriptionId;

  const PrescriptionDetailsScreen({super.key, required this.prescriptionId});

  @override
  State<PrescriptionDetailsScreen> createState() => _PrescriptionDetailsScreenState();
}

class _PrescriptionDetailsScreenState extends State<PrescriptionDetailsScreen> {
  Map<String, dynamic>? _prescriptionData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPrescription();
  }

  Future<void> _fetchPrescription() async {
    try {
      final token = await SecureStorageService.instance.readToken();

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/prescription/${widget.prescriptionId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _prescriptionData = data['prescription'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load prescription';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred while fetching the prescription.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('Prescription', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          foregroundColor: AppConstants.textColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }

    if (_error != null || _prescriptionData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('Prescription', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          foregroundColor: AppConstants.textColor,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            _error ?? 'Prescription not found',
            style: GoogleFonts.plusJakartaSans(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    final rx = _prescriptionData!;
    final doctor = rx['doctorId'] ?? rx['physioId'];
    final docName = doctor is Map ? (doctor['name'] ?? 'Doctor') : 'Doctor';
    
    final specialtyRaw = doctor is Map ? (doctor['specialization'] ?? 'Specialist') : 'Specialist';
    String specialty = 'Specialist';
    if (specialtyRaw is List) {
      specialty = specialtyRaw.join(', ');
    } else if (specialtyRaw != null) {
      specialty = specialtyRaw.toString();
    }
    
    final diagnosis = rx['diagnosis']?.toString() ?? 'N/A';
    final notes = rx['advice']?.toString() ?? 'No additional notes provided.'; // advice maps to notes
    final medicines = rx['medicines'] ?? [];
    
    String dateStr = 'N/A';
    if (rx['createdAt'] != null) {
      try {
        final d = DateTime.parse(rx['createdAt']).toLocal();
        dateStr = '${d.day}/${d.month}/${d.year} at ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Prescription Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.white, 
        foregroundColor: AppConstants.textColor, 
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Info Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(color: AppConstants.primaryColor, shape: BoxShape.circle),
                    child: Center(child: Text(docName[0], style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(docName, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(specialty, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600)),
                  ])),
                ]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                _infoRow(Iconsax.calendar, 'Issued On', dateStr),
                const SizedBox(height: 12),
                _infoRow(Iconsax.health, 'Diagnosis', diagnosis, isBold: true),
              ]),
            ),
            const SizedBox(height: 24),

            // Medicines
            Row(children: [
              const Icon(Iconsax.status_up, size: 20, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Prescribed Medicines', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textColor)),
            ]),
            const SizedBox(height: 12),
            if (medicines.isEmpty)
              _emptyState('No medicines listed')
            else
              ...medicines.asMap().entries.map((entry) => _medicineCard(entry.key + 1, entry.value)),
            
            const SizedBox(height: 24),

            // Advice / Notes
            Text('Doctor\'s Advice', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textColor)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Text(notes, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading prescription PDF...')));
            },
            icon: const Icon(Iconsax.document_download, size: 18),
            label: Text('Download PDF', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor, 
              foregroundColor: Colors.white, 
              padding: const EdgeInsets.symmetric(vertical: 16), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade500),
      const SizedBox(width: 8),
      Text('$label: ', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600)),
      Expanded(child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, color: AppConstants.textColor))),
    ]);
  }

  Widget _medicineCard(int index, Map<String, dynamic> med) {
    final name = (med['name'] ?? med['medicineName'] ?? 'Unknown Medicine').toString();
    final dosage = (med['dosage'] ?? 'N/A').toString();
    final freq = (med['frequency'] ?? 'N/A').toString();
    final duration = (med['duration'] ?? 'N/A').toString();
    final instructions = (med['instructions'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$index', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryColor))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppConstants.textColor))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _medInfo('Dosage', dosage),
          _medInfo('Frequency', freq),
          _medInfo('Duration', duration),
        ]),
        if (instructions.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Iconsax.info_circle, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(child: Text(instructions, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic))),
          ]),
        ],
      ]),
    );
  }

  Widget _medInfo(String label, String value) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textColor)),
    ]));
  }

  Widget _emptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600))),
    );
  }
}
