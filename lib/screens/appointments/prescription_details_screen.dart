import 'package:aadya_plus/models/prescription.dart';
import 'package:aadya_plus/providers/prescription_provider.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PrescriptionDetailsScreen extends StatefulWidget {
  final String prescriptionId;

  const PrescriptionDetailsScreen({super.key, required this.prescriptionId});

  @override
  State<PrescriptionDetailsScreen> createState() => _PrescriptionDetailsScreenState();
}

class _PrescriptionDetailsScreenState extends State<PrescriptionDetailsScreen> {
  Prescription? _prescription;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prescription = await context.read<PrescriptionProvider>().fetchPrescription(widget.prescriptionId);
      if (!mounted) return;
      setState(() {
        _prescription = prescription;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final rx = _prescription;
    if (rx == null) return;
    setState(() => _downloading = true);
    try {
      await context.read<PrescriptionProvider>().downloadAndOpenPdf(rx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('E-Prescription', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textColor,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildPrescription(_prescription!),
      bottomNavigationBar: _prescription == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Iconsax.document_download),
                  label: Text(_downloading ? 'Downloading...' : 'Download signed PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPrescription(Prescription rx) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rx.doctorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (rx.doctorSpecialization.isNotEmpty)
                Text(rx.doctorSpecialization, style: const TextStyle(color: AppConstants.primaryColor)),
              const Divider(height: 26),
              _line('Prescription', rx.prescriptionNumber.isEmpty ? rx.id : rx.prescriptionNumber),
              _line('Issued', DateFormat('dd MMM yyyy, hh:mm a').format(rx.issuedAt)),
              _line('Valid until', DateFormat('dd MMM yyyy').format(rx.validUntil)),
              _line('Status', rx.statusText),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (rx.diagnosis.isNotEmpty) ...[
          _sectionTitle('Diagnosis'),
          _card(child: Text(rx.diagnosis.join(', '))),
          const SizedBox(height: 18),
        ],
        _sectionTitle('Medicines'),
        if (rx.medicines.isEmpty)
          _card(child: const Text('No medicines prescribed.'))
        else
          ...rx.medicines.asMap().entries.map((entry) => _medicineCard(entry.key + 1, entry.value)),
        if (rx.labTests.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionTitle('Recommended tests'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rx.labTests.map((test) {
                final name = (test['testName'] ?? test['name'] ?? 'Test').toString();
                final instructions = (test['instructions'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (instructions.isNotEmpty) Text(instructions, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (rx.advice.isNotEmpty || rx.patientInstructions.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionTitle('Advice'),
          _card(
            child: Text(
              [rx.advice, rx.patientInstructions].where((e) => e.trim().isNotEmpty).join('\n\n'),
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
        if (rx.followupDate != null || rx.followupInstructions.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionTitle('Follow-up'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rx.followupDate != null) Text(DateFormat('dd MMM yyyy').format(rx.followupDate!)),
                if (rx.followupInstructions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(rx.followupInstructions),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _medicineCard(int index, PrescribedMedicine med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 14, child: Text('$index', style: const TextStyle(fontSize: 11))),
              const SizedBox(width: 10),
              Expanded(child: Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 12),
          _line('Dosage', med.dosage.isEmpty ? '—' : med.dosage),
          _line('Frequency', med.frequency.isEmpty ? '—' : med.frequency),
          _line('Duration', med.duration.isEmpty ? '—' : med.duration),
          if (med.prescribedQuantity > 0) _line('Quantity', '${med.prescribedQuantity}${med.unit.isEmpty ? '' : ' ${med.unit}'}'),
          if (med.instructions.isNotEmpty) _line('Instructions', med.instructions),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: child,
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 105, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
