import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../models/prescription.dart';
import '../../providers/pharmacy_provider.dart';
import '../../providers/prescription_provider.dart';
import '../appointments/prescription_details_screen.dart';
import '../pharmacy/nearby_pharmacy_screen.dart';
import '../pharmacy/pharmacy_shop_screen.dart';

/// Prescriptions issued on Aadya Plus: active ones first, each one tap from
/// ordering its medicines.
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PrescriptionProvider>().loadPrescriptions());
  }

  List<Prescription> _filtered(List<Prescription> all) => switch (_filter) {
    'active' => all.where((p) => p.isActive).toList(),
    'expired' => all.where((p) => !p.isActive).toList(),
    _ => all,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrescriptionProvider>();
    final all = [...provider.allPrescriptions]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    final list = _filtered(all);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Prescriptions'),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              children: [
                for (final (key, label) in [
                  ('all', 'All · ${all.length}'),
                  ('active', 'Active · ${provider.activeCount}'),
                  ('expired', 'Past'),
                ]) ...[
                  AppFilterChip(label: label, selected: _filter == key, onTap: () => setState(() => _filter = key)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brand,
              onRefresh: provider.loadPrescriptions,
              child: provider.isLoading && all.isEmpty
                  ? const AppListSkeleton(count: 4)
                  : list.isEmpty
                  ? ListView(
                      children: [
                        AppEmptyState(
                          illustration: provider.error != null && all.isEmpty ? Illustrations.offline : Illustrations.prescription,
                          title: provider.error != null && all.isEmpty
                              ? 'Couldn’t load prescriptions'
                              : _filter == 'active'
                              ? 'No active prescriptions'
                              : 'No prescriptions yet',
                          message: 'Prescriptions your doctor or physio issues after a visit appear here.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => AppEntrance(
                        index: i.clamp(0, 6),
                        child: PrescriptionCard(prescription: list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the shop for [rx]'s medicines, with [rx] chosen for checkout.
void orderPrescription(BuildContext context, Prescription rx) {
  final pharmacy = context.read<PharmacyProvider>();
  pharmacy.preferredPrescriptionId = rx.id;
  final names = rx.medicines.map((m) => m.medicineName).where((n) => n.trim().isNotEmpty).toList();
  Navigator.of(context).push(AppPageRoute(
    builder: (_) => pharmacy.selectedStore == null
        ? const NearbyPharmacyScreen()
        : PharmacyShopScreen(prescribed: names, initialQuery: names.isNotEmpty ? names.first : null),
  ));
}

class PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  const PrescriptionCard({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    final rx = prescription;
    final active = rx.isActive;
    final meds = rx.medicines;
    return AppPressable(
      onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => PrescriptionDetailsScreen(prescriptionId: rx.id))),
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: active ? AppColors.brandVeryLight : AppColors.panel,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(LucideIcons.fileText, size: 19, color: active ? AppColors.brand : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rx.doctorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                            ),
                            Text(
                              '${DateFormat('d MMM y').format(rx.issuedAt)} · ${rx.prescriptionNumber}',
                              style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      active
                          ? AppStatusPill(
                              text: rx.remainingDays <= 3 ? '${rx.remainingDays}d left' : 'Active',
                              color: AppColors.health,
                              background: AppColors.health.withValues(alpha: 0.1),
                            )
                          : PatientStatus.of(rx.isExpired ? 'expired' : rx.status).pill(icon: false),
                    ],
                  ),
                  if (rx.diagnosis.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      rx.diagnosis.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                  if (meds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final m in meds.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.pill, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [m.medicineName, m.dosage, m.frequency].where((e) => e.trim().isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (meds.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 3, left: 19),
                        child: Text('+${meds.length - 3} more', style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary)),
                      ),
                  ],
                ],
              ),
            ),
            if (active && meds.isNotEmpty)
              InkWell(
                onTap: () => orderPrescription(context, rx),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: Container(
                  height: 46,
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.shoppingBag, size: 16, color: ModuleAccent.pharmacy.color),
                      const SizedBox(width: 8),
                      Text(
                        'Order these medicines',
                        style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w800, color: ModuleAccent.pharmacy.color),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
