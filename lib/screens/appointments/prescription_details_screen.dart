import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../models/prescription.dart';
import '../../providers/prescription_provider.dart';
import '../lab_tests/lab_test_screen.dart';
import '../prescriptions/prescriptions_screen.dart' show orderPrescription;

/// An e-prescription as the patient needs it: what's wrong, what to take
/// and how, tests and exercises, advice and the follow-up — with the PDF
/// and ordering one tap away.
class PrescriptionDetailsScreen extends StatefulWidget {
  final String prescriptionId;
  const PrescriptionDetailsScreen({super.key, required this.prescriptionId});

  @override
  State<PrescriptionDetailsScreen> createState() => _PrescriptionDetailsScreenState();
}

class _PrescriptionDetailsScreenState extends State<PrescriptionDetailsScreen> {
  Prescription? _rx;
  String? _error;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rx = await context.read<PrescriptionProvider>().fetchPrescription(widget.prescriptionId);
      if (mounted) setState(() => _rx = rx);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    }
  }

  Future<void> _pdf(Prescription rx) async {
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PrescriptionProvider>().downloadAndOpenPdf(rx);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rx = _rx;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppTopBar(
        title: 'Prescription',
        subtitle: rx?.prescriptionNumber,
        actions: [
          if (rx != null)
            IconButton(
              tooltip: 'Download PDF',
              onPressed: _downloading ? null : () => _pdf(rx),
              icon: _downloading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.download, size: 21),
            ),
        ],
      ),
      body: rx == null
          ? (_error != null
                ? Center(
                    child: AppEmptyState(
                      illustration: Illustrations.offline,
                      title: 'Couldn’t open this prescription',
                      message: _error,
                      actionLabel: 'Try again',
                      onAction: _load,
                    ),
                  )
                : const AppDetailSkeleton())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                AppEntrance(child: _Header(rx: rx)),
                if (rx.diagnosis.isNotEmpty) ...[
                  const _Title('Diagnosis'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final d in rx.diagnosis) AppStatusPill(text: d, color: AppColors.brandDark, background: AppColors.brandVeryLight)],
                  ),
                ],
                if (rx.medicines.isNotEmpty) ...[
                  _Title('Medicines · ${rx.medicines.length}'),
                  for (final (i, m) in rx.medicines.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppEntrance(index: i.clamp(0, 6), child: _MedicineCard(m: m)),
                    ),
                ],
                if (rx.labTests.isNotEmpty) ...[
                  const _Title('Tests advised'),
                  AppCard(
                    child: Column(
                      children: [
                        for (final t in rx.labTests)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(LucideIcons.flaskConical, size: 16, color: ModuleAccent.lab.color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((t['testName'] ?? 'Test').toString(), style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                                      if (t['fastingRequired'] == true || (t['instructions'] ?? '').toString().isNotEmpty)
                                        Text(
                                          [if (t['fastingRequired'] == true) 'Fasting needed', t['instructions']].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                                          style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        ModuleTheme(
                          accent: ModuleAccent.lab,
                          child: AppSecondaryButton(
                            label: 'Book these tests',
                            icon: LucideIcons.flaskConical,
                            color: ModuleAccent.lab.color,
                            onPressed: () => Navigator.of(context).push(AppPageRoute(
                              builder: (_) => LabTestScreen(initialQuery: (rx.labTests.first['testName'] ?? '').toString()),
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (rx.exercises.isNotEmpty) ...[
                  const _Title('Exercises'),
                  AppCard(
                    child: Column(
                      children: [
                        for (final e in rx.exercises)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(LucideIcons.dumbbell, size: 16, color: ModuleAccent.physio.color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    [
                                      e['name'],
                                      if (e['sets'] != null && e['reps'] != null) '${e['sets']} × ${e['reps']}',
                                      e['frequency'],
                                    ].where((v) => v != null && v.toString().isNotEmpty).join(' · '),
                                    style: AppType.sans(fontSize: AppType.body, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (rx.advice.trim().isNotEmpty || rx.patientInstructions.trim().isNotEmpty) ...[
                  const _Title('Advice'),
                  AppCard(
                    child: Text(
                      [rx.advice, rx.patientInstructions].where((e) => e.trim().isNotEmpty).join('\n\n'),
                      style: AppType.sans(fontSize: AppType.body + 0.5, height: 1.5, color: AppColors.textPrimary),
                    ),
                  ),
                ],
                if (rx.followupDate != null) ...[
                  const _Title('Follow-up'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.brandVeryLight, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendarHeart, size: 20, color: AppColors.brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, d MMMM').format(rx.followupDate!),
                                style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                              ),
                              if (rx.followupInstructions.isNotEmpty)
                                Text(rx.followupInstructions, style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: rx == null || !rx.isActive || rx.medicines.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: ModuleTheme(
                  accent: ModuleAccent.pharmacy,
                  child: AppButton(
                    label: 'Order these medicines',
                    icon: LucideIcons.shoppingBag,
                    onPressed: () => orderPrescription(context, rx),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final Prescription rx;
  const _Header({required this.rx});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFE6F4FC), Color(0xFFF5FAFE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.brandLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(name: rx.doctorName, size: 46, radius: 14, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rx.doctorName, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                  if (rx.doctorSpecialization.isNotEmpty)
                    Text(rx.doctorSpecialization, style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Fact('Issued', DateFormat('d MMM y').format(rx.issuedAt)),
            _Fact(rx.isActive ? 'Valid till' : 'Expired on', DateFormat('d MMM y').format(rx.validUntil)),
            _Fact('Status', rx.isActive ? 'Active' : PatientStatus.of(rx.isExpired ? 'expired' : rx.status).label),
          ],
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
        Text(value, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
      ],
    ),
  );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(text, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
  );
}

class _MedicineCard extends StatelessWidget {
  final PrescribedMedicine m;
  const _MedicineCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.pharmacy;
    final dispensed = m.dispensedQuantity > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: accent.veryLight, borderRadius: BorderRadius.circular(11)),
                child: Icon(LucideIcons.pill, size: 18, color: accent.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.medicineName, style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                    if (m.genericName.isNotEmpty)
                      Text(m.genericName, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (dispensed)
                AppStatusPill(
                  text: m.dispensedQuantity >= m.prescribedQuantity && m.prescribedQuantity > 0 ? 'Dispensed' : 'Part dispensed',
                  color: AppColors.health,
                  background: AppColors.health.withValues(alpha: 0.1),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (icon, text) in [
                (LucideIcons.scale, m.dosage),
                (LucideIcons.repeat, m.frequency),
                (LucideIcons.calendarRange, m.duration),
                (LucideIcons.package, m.prescribedQuantity > 0 ? '${m.prescribedQuantity} ${m.unit}'.trim() : ''),
              ])
                if (text.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(text, style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
            ],
          ),
          if (m.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(m.instructions, style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
