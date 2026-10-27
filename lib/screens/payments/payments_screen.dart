import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/app_ui.dart';
import '../../models/payment_record.dart';
import '../../services/payment_service.dart';

/// Every payment made on Aadya Plus, by month, with what it was for.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentRecord>? _payments;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await PaymentService.instance.history();
      if (mounted) setState(() => _payments = p..sort((a, b) => b.date.compareTo(a.date)));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''));
    }
  }

  static (IconData, Color, String) _kind(String type) => switch (type) {
    'appointment' => (LucideIcons.stethoscope, ModuleAccent.doctor.color, 'Consultation'),
    'labtest' => (LucideIcons.flaskConical, ModuleAccent.lab.color, 'Lab tests'),
    'pharmacy_order' => (LucideIcons.pill, ModuleAccent.pharmacy.color, 'Medicines'),
    _ => (LucideIcons.wallet, AppColors.brand, 'Payment'),
  };

  @override
  Widget build(BuildContext context) {
    final all = _payments;
    final list = all == null ? const <PaymentRecord>[] : all.where((p) => _filter == 'all' || p.type == _filter).toList();
    final total = list.fold<double>(0, (s, p) => s + p.amount);
    final months = <String, List<PaymentRecord>>{};
    for (final p in list) {
      months.putIfAbsent(DateFormat('MMMM y').format(p.date), () => []).add(p);
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Payments'),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: all == null && _error == null
            ? const AppListSkeleton(count: 5)
            : all == null
            ? ListView(children: [AppEmptyState(illustration: Illustrations.offline, title: 'Couldn’t load payments', message: _error, actionLabel: 'Try again', onAction: _load)])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  AppEntrance(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE6F4FC), Color(0xFFF5FAFE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.brandLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_filter == 'all' ? 'Total paid' : 'Paid for ${_kind(_filter).$3.toLowerCase()}', style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                AppCountUp(
                                  value: total,
                                  format: appRupees,
                                  style: AppType.sans(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textStrong),
                                ),
                                Text('${list.length} payment${list.length == 1 ? '' : 's'}', style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const AppIllustration(Illustrations.payments, height: 70),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (k, l) in const [('all', 'All'), ('appointment', 'Consultations'), ('labtest', 'Lab tests'), ('pharmacy_order', 'Medicines')]) ...[
                          AppFilterChip(label: l, selected: _filter == k, onTap: () => setState(() => _filter = k)),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  if (list.isEmpty)
                    const AppEmptyState(illustration: Illustrations.payments, title: 'No payments yet', message: 'What you pay for visits, tests and medicines shows up here.')
                  else
                    for (final m in months.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                        child: Text(m.key, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ),
                      Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)),
                        child: Column(
                          children: [
                            for (final (i, p) in m.value.indexed) ...[
                              if (i > 0) const Divider(height: 1, indent: 62),
                              _Row(p: p),
                            ],
                          ],
                        ),
                      ),
                    ],
                ],
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final PaymentRecord p;
  const _Row({required this.p});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _PaymentsScreenState._kind(p.type);
    final detail = [
      p.details['orderNumber'] ?? p.details['labTestNumber'],
      DateFormat('d MMM, h:mm a').format(p.date),
    ].where((e) => e != null && e.toString().isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(appRupees(p.amount), style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
        ],
      ),
    );
  }
}
