import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../core/utils/server_dates.dart';
import '../../features/onboarding/auth_parts.dart' show MethodSwitch;
import '../../providers/lab_test_provider.dart';
import '../lab_tests/lab_test_screen.dart';
import 'diagnostic_order_details_screen.dart';

/// The patient's lab bookings: upcoming and in progress, and finished ones
/// with their reports.
class PathologyScreen extends StatefulWidget {
  const PathologyScreen({super.key});

  @override
  State<PathologyScreen> createState() => _PathologyScreenState();
}

class _PathologyScreenState extends State<PathologyScreen> {
  int _tab = 0;
  static const _done = ['completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<LabTestProvider>().loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LabTestProvider>();
    final active = p.orders.where((o) => !_done.contains(o['status'])).toList();
    final past = p.orders.where((o) => _done.contains(o['status'])).toList();
    final list = _tab == 0 ? active : past;
    return ModuleTheme(
      accent: labAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(
          title: 'My lab tests',
          actions: [
            IconButton(
              tooltip: 'Book tests',
              icon: const Icon(LucideIcons.plus, size: 22),
              onPressed: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const LabTestScreen())),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: MethodSwitch(
                labels: ['In progress${active.isEmpty ? '' : ' · ${active.length}'}', 'Completed'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: labAccent.color,
                onRefresh: () => p.loadOrders(),
                child: list.isEmpty
                    ? ListView(
                        children: [
                          AppEmptyState(
                            illustration: Illustrations.labReport,
                            title: _tab == 0 ? 'No tests booked' : 'No reports yet',
                            message: _tab == 0 ? 'Book a test or health package — many labs collect samples at home.' : null,
                            actionLabel: _tab == 0 ? 'Book a test' : null,
                            onAction: _tab == 0 ? () => Navigator.of(context).push(AppPageRoute(builder: (_) => const LabTestScreen())) : null,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => AppEntrance(
                          index: i.clamp(0, 6),
                          child: LabOrderCard(order: list[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LabOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const LabOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final tests = mapsOf(o['tests']);
    final packages = mapsOf(o['packages']);
    final title = packages.isNotEmpty
        ? (packages.first['packageName'] ?? 'Health package').toString()
        : tests.isEmpty
        ? 'Lab tests'
        : tests.length == 1
        ? (tests.first['testName'] ?? 'Lab test').toString()
        : '${tests.first['testName'] ?? 'Test'} +${tests.length - 1}';
    final day = serverDay(o['scheduledDate']);
    final status = PatientStatus.of(o['status']?.toString());
    final home = o['type'] == 'home_collection';
    return AppPressable(
      onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => DiagnosticOrderDetailsScreen(orderId: idOf(o)))),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: labAccent.veryLight, borderRadius: BorderRadius.circular(14)),
              child: Icon(packages.isNotEmpty ? LucideIcons.packageOpen : LucideIcons.flaskConical, size: 20, color: labAccent.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                  Text(
                    [
                      mapOf(o['pathologyId'])['labName'] ?? 'Lab',
                      if (day != null) DateFormat('d MMM').format(day),
                      home ? 'Home' : 'Lab visit',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  status.pill(),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(appRupees(o['totalAmount']), style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                if (o['status'] == 'completed') ...[
                  const SizedBox(height: 6),
                  Icon(LucideIcons.fileCheck, size: 18, color: labAccent.color),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
