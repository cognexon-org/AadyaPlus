import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_ui.dart';
import '../../core/utils/server_dates.dart';
import '../../providers/lab_test_provider.dart';
import '../../services/patient_records_service.dart';
import '../lab_tests/lab_test_screen.dart' show labAccent;
import '../payments/payment_checkout_screen.dart';

/// A lab order: progress from booking to report, who's collecting the
/// sample, each test's state, results (with flags) once released, and
/// pay / reschedule / cancel / download.
class DiagnosticOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final bool justBooked;
  const DiagnosticOrderDetailsScreen({super.key, required this.orderId, this.justBooked = false});

  @override
  State<DiagnosticOrderDetailsScreen> createState() => _DiagnosticOrderDetailsScreenState();
}

class _DiagnosticOrderDetailsScreenState extends State<DiagnosticOrderDetailsScreen> {
  Map<String, dynamic>? _o;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  static const _steps = [
    ('Booked', LucideIcons.calendarCheck),
    ('Collected', LucideIcons.testTube),
    ('Testing', LucideIcons.flaskConical),
    ('Report', LucideIcons.fileCheck),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      final s = _o?['status'];
      if (s != null && s != 'completed' && s != 'cancelled') _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final o = await context.read<LabTestProvider>().getOrder(widget.orderId);
      if (mounted) setState(() => _o = o);
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''));
    }
  }

  int _step(String status) => switch (status) {
    'requested' || 'scheduled' => 0,
    'sample_collected' => 1,
    'processing' || 'ready_for_review' => 2,
    'completed' => 3,
    _ => -1,
  };

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _load();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel these tests?'),
        content: const Text('Any payment is refunded to how you paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(c, true), child: const Text('Cancel tests')),
        ],
      ),
    );
    if (ok == true && mounted) _run(() => context.read<LabTestProvider>().cancelOrder(widget.orderId), 'Booking cancelled');
  }

  Future<void> _reschedule(Map<String, dynamic> o) async {
    final labId = idOf(o['pathologyId']).isNotEmpty ? idOf(o['pathologyId']) : (o['pathologyId'] ?? '').toString();
    final picked = await showModalBottomSheet<(DateTime, Map<String, dynamic>)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RescheduleSheet(labId: labId),
    );
    if (picked == null || !mounted) return;
    _run(
      () => context.read<LabTestProvider>().reschedule(
        id: widget.orderId,
        date: picked.$1,
        startTime: (picked.$2['startTime'] ?? '').toString(),
        endTime: (picked.$2['endTime'] ?? '').toString(),
      ),
      'Moved to ${DateFormat('EEE, d MMM').format(picked.$1)}',
    );
  }

  Future<void> _report() => _run(() => PatientRecordsService.instance.downloadAndOpenLabReport(widget.orderId), 'Report opened');

  Future<void> _pay(Map<String, dynamic> o) async {
    final paid = await Navigator.of(context).push<bool>(AppPageRoute(
      builder: (_) => PaymentCheckoutScreen(entityType: 'labtest', entityId: widget.orderId, title: 'Lab tests', expectedAmount: asDouble(o['totalAmount'])),
    ));
    if (paid == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return ModuleTheme(
      accent: labAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: 'Lab tests', subtitle: (o?['labTestNumber'] ?? '').toString().isEmpty ? null : o!['labTestNumber'].toString()),
        body: o == null
            ? (_error != null
                  ? Center(child: AppEmptyState(illustration: Illustrations.offline, title: 'Couldn’t load this booking', message: _error, actionLabel: 'Try again', onAction: _load))
                  : const AppDetailSkeleton())
            : RefreshIndicator(color: labAccent.color, onRefresh: _load, child: _body(o)),
        bottomNavigationBar: o == null ? null : _bottom(o),
      ),
    );
  }

  Widget? _bottom(Map<String, dynamic> o) {
    final status = (o['status'] ?? '').toString();
    if (status == 'cancelled') return null;
    final unpaid = o['paymentStatus'] == 'pending' && asDouble(o['totalAmount']) > 0;
    final Widget? button = status == 'completed'
        ? AppButton(label: 'Download report', icon: LucideIcons.download, loading: _busy, onPressed: _report)
        : unpaid
        ? AppButton(label: 'Pay ${appRupees(o['totalAmount'])}', icon: LucideIcons.lock, loading: _busy, onPressed: () => _pay(o))
        : null;
    if (button == null) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: button,
      ),
    );
  }

  Widget _body(Map<String, dynamic> o) {
    final status = (o['status'] ?? '').toString();
    final pill = PatientStatus.of(status);
    final step = _step(status);
    final lab = mapOf(o['pathologyId']);
    final collector = mapOf(o['assignedPhlebotomistId']);
    final tests = mapsOf(o['tests']);
    final home = o['type'] == 'home_collection';
    final day = serverDay(o['scheduledDate']);
    final when = [
      if (day != null) DateFormat('EEE, d MMM').format(day),
      if ((o['startTime'] ?? '').toString().isNotEmpty) '${o['startTime']}${(o['endTime'] ?? '').toString().isNotEmpty ? '–${o['endTime']}' : ''}',
    ].join(' · ');
    final early = ['requested', 'scheduled'].contains(status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        if (widget.justBooked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppEntrance(
              child: Row(
                children: [
                  const AppIllustration(Illustrations.success, height: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Booked! ${home ? 'A collector will come at your slot.' : 'See you at the lab.'}',
                      style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: pill.background, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(pill.icon, size: 22, color: pill.color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(pill.label, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: pill.color))),
                ],
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${home ? 'Home collection' : 'Lab visit'} · $when', style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary)),
              ],
              if (step >= 0) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < _steps.length; i++) ...[
                      Column(
                        children: [
                          AnimatedContainer(
                            duration: AppMotion.medium,
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: i <= step ? labAccent.color : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: i <= step ? labAccent.color : AppColors.borderStrong, width: 1.5),
                            ),
                            child: Icon(_steps[i].$2, size: 14, color: i <= step ? Colors.white : AppColors.textTertiary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _steps[i].$1,
                            style: AppType.sans(fontSize: AppType.micro, fontWeight: i == step ? FontWeight.w800 : FontWeight.w500, color: i <= step ? AppColors.textStrong : AppColors.textTertiary),
                          ),
                        ],
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: i < step ? 1 : 0),
                              duration: const Duration(milliseconds: 700),
                              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: AppColors.borderStrong, color: labAccent.color),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        if (home && collector.isNotEmpty && early) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                AppAvatar(name: (collector['name'] ?? 'Collector').toString(), size: 44, color: labAccent.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((collector['name'] ?? 'Sample collector').toString(), style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                      Text(
                        o['collectionStatus'] == 'en_route' ? 'On the way to you' : o['collectionStatus'] == 'arrived' ? 'Has arrived' : 'Will collect your sample',
                        style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if ((collector['phone'] ?? '').toString().isNotEmpty)
                  IconButton.filled(
                    tooltip: 'Call',
                    style: IconButton.styleFrom(backgroundColor: labAccent.color),
                    onPressed: () => launchUrl(Uri.parse('tel:${collector['phone']}')),
                    icon: const Icon(LucideIcons.phone, size: 18),
                  ),
              ],
            ),
          ),
        ],
        if (o['fastingRequired'] == true && early) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(LucideIcons.utensilsCrossed, size: 17, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Text('Fast for 8–12 hours before your slot. Water is fine.', style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Title('Tests · ${tests.length}'),
        for (final t in tests) Padding(padding: const EdgeInsets.only(bottom: 10), child: _TestResult(test: t)),
        if ((o['resultNotes'] ?? '').toString().isNotEmpty) ...[
          AppCard(child: Text(o['resultNotes'].toString(), style: AppType.sans(fontSize: AppType.body, height: 1.45, color: AppColors.textPrimary))),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        const _Title('Lab'),
        AppCard(
          child: Row(
            children: [
              Icon(LucideIcons.building2, size: 19, color: labAccent.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((lab['labName'] ?? 'Lab').toString(), style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                    if (lab['address'] is Map)
                      Text(
                        [lab['address']['street'] ?? lab['address']['line1'], lab['address']['city']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                        style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if ((lab['phone'] ?? '').toString().isNotEmpty)
                IconButton(tooltip: 'Call lab', onPressed: () => launchUrl(Uri.parse('tel:${lab['phone']}')), icon: Icon(LucideIcons.phone, size: 18, color: labAccent.color)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Title('Bill'),
        AppCard(
          child: Column(
            children: [
              _Line('Tests', appRupees(o['subtotal'] ?? tests.fold<double>(0, (s, t) => s + asDouble(t['price'])))),
              if (asDouble(o['collectionCharges']) > 0) _Line('Home collection', appRupees(o['collectionCharges'])),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(child: Text('Total', style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong))),
                  PatientStatus.of(o['paymentStatus'] == 'pending' ? 'payment_pending' : o['paymentStatus']?.toString()).pill(icon: false),
                  const SizedBox(width: 8),
                  Text(appRupees(o['totalAmount']), style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                ],
              ),
            ],
          ),
        ),
        if (early) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: AppSecondaryButton(label: 'Reschedule', icon: LucideIcons.calendarClock, onPressed: _busy ? null : () => _reschedule(o))),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : _cancel,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size.fromHeight(46)),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
  );
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppType.sans(fontSize: AppType.body, color: AppColors.textSecondary))),
        Text(value, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w600, color: AppColors.textStrong)),
      ],
    ),
  );
}

class _TestResult extends StatelessWidget {
  final Map<String, dynamic> test;
  const _TestResult({required this.test});

  static Color _flag(String? f) => switch (f) {
    'high' || 'low' => AppColors.warning,
    'critical' => AppColors.error,
    _ => AppColors.health,
  };

  @override
  Widget build(BuildContext context) {
    final results = mapsOf(test['results']);
    final status = PatientStatus.of(test['status']?.toString());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderStrong)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((test['testName'] ?? 'Test').toString(), style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
              ),
              status.pill(icon: false),
            ],
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final r in results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((r['parameter'] ?? '').toString(), style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if ((r['normalRange'] ?? '').toString().isNotEmpty)
                            Text('Normal ${r['normalRange']}', style: AppType.sans(fontSize: AppType.micro, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    Text(
                      '${r['value'] ?? '–'} ${r['unit'] ?? ''}'.trim(),
                      style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _flag(r['flag']?.toString())),
                    ),
                    const SizedBox(width: 8),
                    if (r['flag'] != null && r['flag'] != 'normal')
                      AppStatusPill(
                        text: sentenceCase(r['flag'].toString()),
                        color: _flag(r['flag'].toString()),
                        background: _flag(r['flag'].toString()).withValues(alpha: 0.1),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RescheduleSheet extends StatefulWidget {
  final String labId;
  const _RescheduleSheet({required this.labId});

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1);
  List<Map<String, dynamic>>? _slots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _slots = null);
    try {
      final s = await context.read<LabTestProvider>().slots(widget.labId, _date);
      if (mounted) setState(() => _slots = s.where((x) => x['isAvailable'] != false && (x['availableCapacity'] as num? ?? 1) > 0).toList());
    } catch (_) {
      if (mounted) setState(() => _slots = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a new slot', style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
            const SizedBox(height: 14),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = start.add(Duration(days: i));
                  final sel = d == _date;
                  return AppPressable(
                    onTap: () {
                      setState(() => _date = d);
                      _load();
                    },
                    child: Container(
                      width: 54,
                      decoration: BoxDecoration(color: sel ? labAccent.color : AppColors.panel, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('EEE').format(d), style: AppType.sans(fontSize: AppType.caption, color: sel ? Colors.white70 : AppColors.textSecondary)),
                          Text('${d.day}', style: AppType.sans(fontSize: 18, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textStrong)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (_slots == null)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_slots!.isEmpty)
              Text('No free slots that day.', style: AppType.sans(fontSize: AppType.body, color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _slots!)
                    ActionChip(
                      label: Text('${s['startTime']}'),
                      onPressed: () => Navigator.pop(context, (_date, s)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
